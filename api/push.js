// Push-notification sender: turns a new `notifications` row into an FCM push to
// every registered device of that audience (web + Android).
//
// Invoked by a Supabase Database Webhook on INSERT into `notifications`
// (Supabase → Database → Webhooks → HTTP request to /api/push). Can also be
// called directly with { audience, title, message } for testing.
//
// Required Vercel environment variables:
//   SUPABASE_URL               e.g. https://xxxx.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY  Project Settings → API → service_role (secret!)
//   FCM_SERVICE_ACCOUNT        the full Firebase service-account JSON (as a
//                              single-line string) from Firebase Console →
//                              Project settings → Service accounts → Generate
//                              new private key. Provides project_id,
//                              client_email and private_key.
//   PUSH_WEBHOOK_SECRET        (optional) shared secret; if set, the caller must
//                              send it as the `x-webhook-secret` header.

const jwt = require('jsonwebtoken');

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') {
    try { return JSON.parse(req.body || '{}'); } catch { return {}; }
  }
  return await new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => { data += c; });
    req.on('end', () => {
      try { resolve(JSON.parse(data || '{}')); } catch { resolve({}); }
    });
  });
}

function serviceAccount() {
  const raw = process.env.FCM_SERVICE_ACCOUNT;
  if (!raw) throw new Error('missing FCM_SERVICE_ACCOUNT');
  const sa = typeof raw === 'string' ? JSON.parse(raw) : raw;
  // Vercel env values often store the private key with literal "\n" sequences.
  if (sa.private_key && sa.private_key.includes('\\n')) {
    sa.private_key = sa.private_key.replace(/\\n/g, '\n');
  }
  return sa;
}

// Exchange the service-account JWT for a short-lived FCM access token.
async function getAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  const assertion = jwt.sign(
    { scope: FCM_SCOPE },
    sa.private_key,
    {
      algorithm: 'RS256',
      issuer: sa.client_email,
      audience: OAUTH_TOKEN_URL,
      subject: sa.client_email,
      expiresIn: 3600,
      keyid: sa.private_key_id,
    },
  );
  const params = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  const r = await fetch(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });
  const json = await r.json().catch(() => ({}));
  if (!r.ok || !json.access_token) {
    throw new Error(`FCM auth failed: ${json.error_description || json.error || r.status}`);
  }
  return json.access_token;
}

// Fetch registration tokens for an audience via the Supabase REST API.
async function tokensForAudience(audience) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY');
  const r = await fetch(
    `${url}/rest/v1/device_tokens?select=token&audience=eq.${encodeURIComponent(audience)}`,
    { headers: { apikey: key, Authorization: `Bearer ${key}` } },
  );
  if (!r.ok) throw new Error(`token lookup failed: HTTP ${r.status}`);
  const rows = await r.json().catch(() => []);
  return rows.map((x) => x.token).filter(Boolean);
}

async function deleteToken(token) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  try {
    await fetch(
      `${url}/rest/v1/device_tokens?token=eq.${encodeURIComponent(token)}`,
      { method: 'DELETE', headers: { apikey: key, Authorization: `Bearer ${key}` } },
    );
  } catch (_) { /* best effort */ }
}

async function sendOne(projectId, accessToken, token, title, body, link) {
  const message = {
    message: {
      token,
      notification: { title, body },
      webpush: {
        notification: { icon: '/icons/Icon-192.png' },
        fcm_options: link ? { link } : undefined,
      },
      android: {
        priority: 'high',
        notification: { channel_id: 'fomrals_default' },
      },
    },
  };
  const r = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    },
  );
  if (r.ok) return { ok: true };
  const err = await r.json().catch(() => ({}));
  const status = err?.error?.details?.[0]?.errorCode || err?.error?.status || r.status;
  // Stale tokens (uninstalled app / revoked permission) — prune them.
  if (status === 'UNREGISTERED' || status === 'INVALID_ARGUMENT' || r.status === 404) {
    await deleteToken(token);
  }
  return { ok: false, status };
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-webhook-secret');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const secret = process.env.PUSH_WEBHOOK_SECRET;
  if (secret && req.headers['x-webhook-secret'] !== secret) {
    return res.status(401).json({ error: 'bad webhook secret' });
  }

  try {
    const body = await readBody(req);
    // Supabase webhook shape: { type, table, record, ... }. Direct-call shape:
    // { audience, title, message }.
    const record = body.record || body;
    const audience = record.audience || 'management';
    const title = record.title || 'Fomra LS';
    const text = record.message || '';
    const link = process.env.PUSH_CLICK_URL || 'https://fomra-ls.vercel.app';

    const tokens = await tokensForAudience(audience);
    if (tokens.length === 0) {
      return res.status(200).json({ ok: true, sent: 0, note: 'no devices for audience' });
    }

    const sa = serviceAccount();
    const accessToken = await getAccessToken(sa);
    const results = await Promise.all(
      tokens.map((t) => sendOne(sa.project_id, accessToken, t, title, text, link)),
    );
    const sent = results.filter((r) => r.ok).length;
    return res.status(200).json({ ok: true, sent, failed: results.length - sent });
  } catch (e) {
    return res.status(500).json({ error: String(e && e.message ? e.message : e) });
  }
};
