// Admin endpoint: invite / provision / reset / delete Supabase Auth users.
//
// Two onboarding paths, both driven from Add Employee:
//   • invite    — email the employee a link to set their OWN password (needs
//                 Supabase SMTP configured; falls back to a recovery email for
//                 an address that already has a login).
//   • provision — create the login here with a known password and hand it over
//                 directly (no email, no SMTP dependency).
// Creating an auth user requires the service_role key, which must never live in
// the client, so this serverless function holds it server-side and is callable
// ONLY by a signed-in management user (verified via their Supabase access token).
//
// Required Vercel environment variables:
//   SUPABASE_URL                 e.g. https://irjgtudyxzzvgbbrxmgq.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY    Project Settings → API → service_role (secret!)
//   MANAGEMENT_EMAIL             defaults to management@fomrahousing.in
//   APP_URL                      base URL for the set-password link (invite);
//                                defaults to https://fomra-ls.vercel.app
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
// Supabase's built-in email service is rate-limited (a few per hour) and is not
// meant for production — a custom SMTP provider must be configured for invites
// to actually send.
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
    return 'Supabase could not send the set-password email. Configure SMTP in ' +
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

  // Optional profile metadata carried onto the auth user so the account knows
  // its own name/role. The app reads permissions from employee_profiles, so
  // this is informational only. Every role is treated identically.
  const designation = (body.designation || '').trim();
  const fullName = (body.fullName || '').trim();
  const userMetadata = {};
  if (fullName) userMetadata.full_name = fullName;
  if (designation) userMetadata.designation = designation;

  const base = `${SUPABASE_URL}/auth/v1/admin/users`;
  const headers = {
    apikey: SERVICE_ROLE,
    Authorization: `Bearer ${SERVICE_ROLE}`,
    'Content-Type': 'application/json',
  };

  // Where the invite / recovery email's "set password" link should land the
  // user. Must be listed in Supabase → Authentication → URL Configuration.
  const APP_URL = (process.env.APP_URL || 'https://fomra-ls.vercel.app').replace(/\/$/, '');
  const REDIRECT_TO = `${APP_URL}/set-password`;

  try {
    if (action === 'invite') {
      // Send an invite email so the recipient sets their OWN password via the
      // app's /set-password screen — no password is set here. If the address is
      // already registered, fall back to a password-recovery email (its link
      // also lands on /set-password), so re-inviting an existing user works.
      const r = await fetch(
        `${SUPABASE_URL}/auth/v1/invite?redirect_to=${encodeURIComponent(REDIRECT_TO)}`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({
            email,
            ...(Object.keys(userMetadata).length ? { data: userMetadata } : {}),
          }),
        }
      );
      if (r.ok) return res.status(200).json({ ok: true, invited: true });
      const err = await r.json().catch(() => ({}));
      const rawMsg = `${err.msg || err.error_description || err.message || ''}`.trim();
      const msg = rawMsg.toLowerCase();
      // Existing user is NOT an email failure — its message ("... already
      // registered") would be misread as one, so check it first.
      if (r.status === 422 || msg.includes('already') || msg.includes('registered') || msg.includes('exists')) {
        const rec = await fetch(
          `${SUPABASE_URL}/auth/v1/recover?redirect_to=${encodeURIComponent(REDIRECT_TO)}`,
          { method: 'POST', headers, body: JSON.stringify({ email }) }
        );
        if (rec.ok) return res.status(200).json({ ok: true, invited: false, recovered: true });
        const rerr = await rec.json().catch(() => ({}));
        const rrawMsg = `${rerr.msg || rerr.error_description || rerr.message || ''}`.trim();
        const rmapped = explainEmailError(rec.status, rrawMsg.toLowerCase());
        return res.status(rec.status).json({
          error: rmapped
            ? (rrawMsg ? `${rmapped}\n\nRaw error (HTTP ${rec.status}): ${rrawMsg}` : rmapped)
            : (rrawMsg || 'could not send password email'),
        });
      }
      const mapped = explainEmailError(r.status, msg);
      if (mapped) {
        return res.status(r.status).json({
          error: rawMsg ? `${mapped}\n\nRaw error (HTTP ${r.status}): ${rawMsg}` : mapped,
        });
      }
      return res.status(r.status).json({ error: rawMsg || 'invite failed' });
    }

    if (action === 'provision') {
      // Create a confirmed auth user with a known password so they can sign in
      // immediately — no invite email, no email verification. Idempotent:
      // "already exists" is treated as ok (the caller then sets the password
      // via the reset action).
      const r = await fetch(base, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          email,
          password,
          email_confirm: true,
          ...(Object.keys(userMetadata).length ? { user_metadata: userMetadata } : {}),
        }),
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
