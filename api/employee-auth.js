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
  const MGMT_EMAIL = (process.env.MANAGEMENT_EMAIL || 'management@fomrahousing.in').toLowerCase();
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return res.status(500).json({ error: 'server not configured (missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)' });
  }

  // 1) Authenticate the caller: their access token must be a valid session
  //    belonging to the management account.
  const authz = req.headers['authorization'] || '';
  const token = authz.startsWith('Bearer ') ? authz.slice(7) : '';
  if (!token) return res.status(401).json({ error: 'missing bearer token' });
  try {
    const who = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${token}` },
    });
    if (!who.ok) return res.status(401).json({ error: 'invalid session' });
    const user = await who.json();
    if ((user.email || '').toLowerCase() !== MGMT_EMAIL) {
      return res.status(403).json({ error: 'management only' });
    }
  } catch (e) {
    return res.status(401).json({ error: 'could not verify session' });
  }

  const body = await readBody(req);
  const action = body.action;
  const email = (body.email || '').trim().toLowerCase();
  const password = body.password || DEFAULT_PASSWORD;
  if (!email) return res.status(400).json({ error: 'email required' });

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
      const r = await fetch(
        `${SUPABASE_URL}/auth/v1/invite?redirect_to=${encodeURIComponent(REDIRECT_TO)}`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({ email }),
        }
      );
      if (r.ok) return res.status(200).json({ ok: true, invited: true });
      const err = await r.json().catch(() => ({}));
      const msg = `${err.msg || err.error_description || err.message || ''}`.toLowerCase();
      if (r.status === 422 || msg.includes('already') || msg.includes('registered') || msg.includes('exists')) {
        // The user already exists → an invite won't re-send. Send a password
        // recovery email instead; its link also lands on /set-password (the app
        // handles type=recovery), so they can (re)set their password.
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
        return res.status(rec.status).json({
          error: rerr.msg || rerr.message || 'could not send password email',
        });
      }
      return res.status(r.status).json({ error: err.msg || err.message || 'invite failed' });
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

    return res.status(400).json({ error: 'unknown action (use "invite", "provision" or "reset")' });
  } catch (e) {
    return res.status(500).json({ error: String(e && e.message ? e.message : e) });
  }
};
