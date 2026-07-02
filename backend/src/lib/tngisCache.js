// Shared persistent cache for TNGIS rate_limit_land_details results.
//
// rate_limit_land_details is throttled per IP. The GI Viewer website survives
// because every browser has its own quota, but our backend funnels every lookup
// through one server IP and quickly hits "Too many requests". Caching each
// resolved point in Supabase means once ANY user resolves a coordinate, the
// exact survey/sub is served to everyone from the DB — surviving serverless
// cold starts and avoiding the upstream throttle entirely for repeat/near taps.

const https = require('https');

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://irjgtudyxzzvgbbrxmgq.supabase.co';
const SUPABASE_KEY =
  process.env.SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
  '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlyamd0dWR5eHp6dmdiYnJ4bWdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTEwMDksImV4cCI6MjA5NzY4NzAwOX0' +
  '.l6xVEkarfrVLoKT86oaZrTFobTZaIr9ZgBrdmlHJ6jU';

const HOST = new URL(SUPABASE_URL).hostname;
const TABLE = 'tngis_land_cache';

function request(method, path, body, extraHeaders = {}) {
  return new Promise((resolve) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        hostname: HOST,
        path,
        method,
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json',
          ...extraHeaders,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => { data += c; });
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, json: data ? JSON.parse(data) : null });
          } catch (_) {
            resolve({ status: res.statusCode, json: null });
          }
        });
      },
    );
    req.setTimeout(6000, () => { req.destroy(); resolve({ status: 0, json: null }); });
    req.on('error', () => resolve({ status: 0, json: null }));
    if (payload) req.write(payload);
    req.end();
  });
}

/** Cached land-details `data` object for a coordinate key, or null. */
async function getCachedLandDetails(key) {
  const path =
    `/rest/v1/${TABLE}?coord_key=eq.${encodeURIComponent(key)}&select=data,updated_at`;
  const { status, json } = await request('GET', path);
  if (status === 200 && Array.isArray(json) && json.length) {
    return { data: json[0].data, updatedAt: json[0].updated_at };
  }
  return null;
}

/** Upsert a resolved land-details result. Fire-and-forget; never throws. */
async function putCachedLandDetails(key, data) {
  const path = `/rest/v1/${TABLE}?on_conflict=coord_key`;
  await request(
    'POST',
    path,
    [{ coord_key: key, data, updated_at: new Date().toISOString() }],
    { Prefer: 'resolution=merge-duplicates,return=minimal' },
  );
}

module.exports = { getCachedLandDetails, putCachedLandDetails };
