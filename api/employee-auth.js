// Admin endpoint: provision / reset Supabase Auth users for employees.
//
// Why this exists: creating an auth user (so an employee can get a REAL
// authenticated session, which lets us lock RLS down to `authenticated`)
// requires the service_role key, which must never live in the client. This
// serverless function holds it server-side and is callable ONLY by a signed-in
// management user (verified via their Supabase access token).
//
// Required Vercel environment variables:
//   SUPABASE_URL                 e.g. https://irjgtudyxzzvgbbrxmgq.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY    Project Settings → API → service_role (secret!)
//   MANAGEMENT_EMAIL             defaults to management@fomrahousing.in
//
// Auth: caller must send `Authorization: Bearer <management access token>`.
// The token is validated against Supabase and must belong to MANAGEMENT_EMAIL.

const DEFAULT_PASSWORD = process.env.DEFAULT_ACCOUNT_PASSWORD || 'fomra@2024';

// Only reflect an allow-listed origin. Configure via ALLOWED_ORIGINS
// (comma-separated); defaults to the production web app origin.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean)
  : ['https://fomra-ls.vercel.app']);

function cors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') {
    try { return JSON.parse(req.body || '{}'); } catch { return {}; }
  }
  return await new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => (data += c));
    req.on('end', () => { try { resolve(JSON.parse(data || '{}')); } catch { resolve({}); } });
    req.on('error', () => resolve({}));
  });
}

// Turn GoTrue's opaque email failures into something management can act on.
// These are the real-world causes of "employee created but invite failed":
// Supabase's built-in email service is rate-limited (a few per hour) and is
// not meant for production — a custom SMTP provider must be configured.
function explainEmailError(status, msg) {
  if (status === 429 || msg.includes('rate limit') || msg.includes('too many')) {
    return 'Email rate limit reached. Supabase\'s built-in email service only ' +
      'allows a few messages per hour — configure a custom SMTP provider in ' +
      'Supabase → Authentication → Emails → SMTP Settings, then re-send.';
  }
  if (
    msg.includes('error sending') ||
    msg.includes('smtp') ||
    msg.includes('send email') ||
    msg.includes('sending email')
  ) {
    // NB: deliberately not matching a bare 'mail' — it also matches "email",
    // which appears in unrelated errors like "email already registered".
    return 'Supabase could not send the invite email. Configure SMTP in ' +
      'Supabase → Authentication → Emails → SMTP Settings (and make sure the ' +
      '"Invite user" template + Site URL / redirect URLs are set), then re-send.';
  }
  return null;
}

async function findUserIdByEmail(base, headers, email) {
  for (let page = 1; page <= 10; page++) {
    const r = await fetch(`${base}?page=${page}&per_page=200`, { headers });
    if (!r.ok) break;
    const data = await r.json();
    const users = Array.isArray(data) ? data : (data.users || []);
    const found = users.find((u) => (u.email || '').toLowerCase() === email);
    if (found) return found.id;
    if (users.length < 200) break;
  }
  return null;
}

module.exports = async (req, res) => {
  cors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY;
  // Accept the configured management email AND the app's built-in one, so a
  // drifted MANAGEMENT_EMAIL env var can never lock every admin out.
  const MGMT_EMAILS = new Set(
    [process.env.MANAGEMENT_EMAIL, 'management@fomrahousing.in']
      .filter(Boolean)
      .map((s) => s.trim().toLowerCase())
  );
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return res.status(500).json({ error: 'server not configured (missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)' });
  }

  // 1) Authenticate the caller: their access token must be a valid session
  //    belonging to a management account.
  const authz = req.headers['authorization'] || '';
  const token = authz.startsWith('Bearer ') ? authz.slice(7) : '';
  if (!token) return res.status(401).json({ error: 'missing bearer token' });
  let callerEmail = '';
  try {
    const who = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${token}` },
    });
    if (!who.ok) return res.status(401).json({ error: 'invalid session' });
    const user = await who.json();
    callerEmail = (user.email || '').toLowerCase();
  } catch (e) {
    return res.status(401).json({ error: 'could not verify session' });
  }
  if (!MGMT_EMAILS.has(callerEmail)) {
    return res.status(403).json({
      error:
        `Not authorised — signed in as ${callerEmail || 'an unknown account'}, ` +
        'which is not the management account this server accepts. Sign in as the ' +
        'management account. No changes were made.',
    });
  }

  const body = await readBody(req);
  const action = body.action;
  const email = (body.email || '').trim().toLowerCase();
  const password = body.password || DEFAULT_PASSWORD;
  if (!email) return res.status(400).json({ error: 'email required' });

  // Optional invite metadata. The app's permissions read the designation from
  // employee_profiles, not from here — this carries it onto the auth user so
  // the invited account knows its own role and the email template can greet
  // them by name/role. Every designation is treated the same: Executive,
  // Reporting Manager, Head and Management all take this identical path.
  const designation = (body.designation || '').trim();
  const fullName = (body.fullName || '').trim();

  const base = `${SUPABASE_URL}/auth/v1/admin/users`;
  const headers = {
    apikey: SERVICE_ROLE,
    Authorization: `Bearer ${SERVICE_ROLE}`,
    'Content-Type': 'application/json',
  };

  // Where the invite email's "set password" link should land the user.
  const APP_URL = (process.env.APP_URL || 'https://fomra-ls.vercel.app').replace(/\/$/, '');
  const REDIRECT_TO = `${APP_URL}/set-password`;

  try {
    if (action === 'invite') {
      // Send an invite email. The recipient clicks the link and sets their own
      // password (handled by the app's /set-password screen). No password is
      // ever set here. Idempotent-ish: an already-registered email returns ok.
      const data = {};
      if (fullName) data.full_name = fullName;
      if (designation) data.designation = designation;

      const r = await fetch(
        `${SUPABASE_URL}/auth/v1/invite?redirect_to=${encodeURIComponent(REDIRECT_TO)}`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({
            email,
            // GoTrue stores `data` as the new user's user_metadata.
            ...(Object.keys(data).length ? { data } : {}),
          }),
        }
      );
      if (r.ok) return res.status(200).json({ ok: true, invited: true });
      const err = await r.json().catch(() => ({}));
      const rawMsg = `${err.msg || err.error_description || err.message || ''}`.trim();
      const msg = rawMsg.toLowerCase();
      // Check "already registered" FIRST — an existing user is not an email
      // failure, and its message ("email address ... already registered")
      // would otherwise be misread as one. Send a password recovery email
      // instead; its link also lands on /set-password (the app handles
      // type=recovery), so they can (re)set their password.
      if (r.status === 422 || msg.includes('already') || msg.includes('registered') || msg.includes('exists')) {
        const rec = await fetch(
          `${SUPABASE_URL}/auth/v1/recover?redirect_to=${encodeURIComponent(REDIRECT_TO)}`,
          {
            method: 'POST',
            headers,
            body: JSON.stringify({ email }),
          }
        );
        if (rec.ok) {
          return res.status(200).json({ ok: true, invited: false, recovered: true });
        }
        const rerr = await rec.json().catch(() => ({}));
        const rrawMsg = `${rerr.msg || rerr.error_description || rerr.message || ''}`.trim();
        const rmsg = rrawMsg.toLowerCase();
        const rmapped = explainEmailError(rec.status, rmsg);
        return res.status(rec.status).json({
          error: rmapped
              ? (rrawMsg ? `${rmapped}\n\nRaw error (HTTP ${rec.status}): ${rrawMsg}` : rmapped)
              : (rrawMsg || 'could not send password email'),
        });
      }
      // A genuine send failure (not an existing user) → explain SMTP, with the
      // raw detail appended so a stuck setup is diagnosable.
      const mapped = explainEmailError(r.status, msg);
      if (mapped) {
        return res.status(r.status).json({
          error: rawMsg ? `${mapped}\n\nRaw error (HTTP ${r.status}): ${rawMsg}` : mapped,
        });
      }
      return res.status(r.status).json({ error: rawMsg || 'invite failed' });
    }

    if (action === 'provision') {
      // Create a confirmed auth user. Idempotent: treat "already exists" as ok.
      const r = await fetch(base, {
        method: 'POST',
        headers,
        body: JSON.stringify({ email, password, email_confirm: true }),
      });
      if (r.ok) return res.status(200).json({ ok: true, created: true });
      const err = await r.json().catch(() => ({}));
      const msg = `${err.msg || err.error_description || err.message || ''}`.toLowerCase();
      if (r.status === 422 || msg.includes('already') || msg.includes('registered') || msg.includes('exists')) {
        return res.status(200).json({ ok: true, created: false, existed: true });
      }
      return res.status(r.status).json({ error: err.msg || err.message || 'create failed' });
    }

    if (action === 'delete') {
      // Permanently remove the Supabase Auth user so the address can never sign
      // in again. Deleting only the employee_profiles row leaves the login
      // intact, which is why this exists.
      //
      // Refuse the management account outright — deleting it would lock every
      // admin action (including this endpoint) out of the project.
      if (MGMT_EMAILS.has(email)) {
        return res.status(403).json({ error: 'the management account cannot be deleted' });
      }
      const id = await findUserIdByEmail(base, headers, email);
      // Idempotent: no auth user (never provisioned, or already deleted) is
      // success — the caller's goal is "this address cannot sign in".
      if (!id) return res.status(200).json({ ok: true, deleted: false, existed: false });
      const r = await fetch(`${base}/${id}`, { method: 'DELETE', headers });
      if (r.ok) return res.status(200).json({ ok: true, deleted: true });
      const err = await r.json().catch(() => ({}));
      return res.status(r.status).json({ error: err.msg || err.message || 'delete failed' });
    }

    if (action === 'reset') {
      const id = await findUserIdByEmail(base, headers, email);
      if (!id) return res.status(404).json({ error: 'no auth user for that email' });
      const r = await fetch(`${base}/${id}`, {
        method: 'PUT',
        headers,
        body: JSON.stringify({ password }),
      });
      if (r.ok) return res.status(200).json({ ok: true });
      const err = await r.json().catch(() => ({}));
      return res.status(r.status).json({ error: err.msg || err.message || 'reset failed' });
    }

    return res.status(400).json({ error: 'unknown action (use "invite", "provision", "reset" or "delete")' });
  } catch (e) {
    return res.status(500).json({ error: String(e && e.message ? e.message : e) });
  }
};
