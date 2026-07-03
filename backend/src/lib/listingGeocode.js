const https = require('https');

// Locality → coords cache, persisted across requests. Only successful lookups
// are cached (misses/timeouts are retried later), so a locality is geocoded at
// most once ever — greatly reducing dependence on the (flaky) live geocoder.
const _geoCache = new Map();

function httpGetJson(url, headers, timeoutMs) {
  return new Promise((resolve) => {
    const req = https.get(url, { headers }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        try { resolve(JSON.parse(Buffer.concat(chunks).toString())); }
        catch { resolve(null); }
      });
      res.on('error', () => resolve(null));
    });
    req.setTimeout(timeoutMs, () => { req.destroy(); resolve(null); });
    req.on('error', () => resolve(null));
  });
}

async function geocodeOne(query) {
  if (_geoCache.has(query)) return _geoCache.get(query);

  // 1) Photon (fast, no rate limit) — primary.
  const photon = await httpGetJson(
    `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&limit=1&lang=en`,
    { 'User-Agent': 'FomraLS/1.0' },
    2500,
  );
  const pf = photon?.features?.[0];
  if (pf?.geometry?.coordinates) {
    const g = { lat: pf.geometry.coordinates[1], lng: pf.geometry.coordinates[0] };
    _geoCache.set(query, g);
    return g;
  }

  // 2) Nominatim fallback when Photon is down/misses (rate-limited, so only hit
  //    when needed; cached results mean we rarely call it in bulk).
  const nom = await httpGetJson(
    `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(query)}`,
    { 'User-Agent': 'FomraLS/1.0 (in.fomrahousing)', 'Accept-Language': 'en' },
    4500,
  );
  if (Array.isArray(nom) && nom[0]?.lat && nom[0]?.lon) {
    const g = { lat: parseFloat(nom[0].lat), lng: parseFloat(nom[0].lon) };
    _geoCache.set(query, g);
    return g;
  }

  return null; // not cached — retry on a later request
}

function geocodeQueryForListing(l, city) {
  const cityNorm = (city || 'Chennai').replace(/\s+district\s*$/i, '').trim();
  const name = (l.projectName || '').trim();
  const locality = (l.locality || '').trim();
  const addr = (locality || l.address || '').trim();
  const pin = addr.match(/\b(\d{6})\b/);
  if (pin) return `${pin[1]}, Tamil Nadu, India`;
  if (locality && locality.length > 2 && locality !== name) {
    return `${locality}, ${cityNorm}, Tamil Nadu, India`;
  }
  if (name && name.length > 2) return `${name}, ${cityNorm}, Tamil Nadu, India`;
  const short = addr.slice(0, 60).replace(/\s+/g, ' ').trim();
  if (short.length > 5) return `${short}, ${cityNorm}, Tamil Nadu, India`;
  return `${cityNorm}, Tamil Nadu, India`;
}

/** Attach lat/lng to listings (priced first) for radius filtering. */
async function geocodeListings(listings, city, maxCount = 50) {
  if (!listings.length) return listings;

  const sorted = [...listings].sort((a, b) => {
    const ap = (a.pricePerSqft || 0) + (a.priceRupees || 0) / 1e6;
    const bp = (b.pricePerSqft || 0) + (b.priceRupees || 0) / 1e6;
    return bp - ap;
  });

  const needGeo = sorted.filter((l) => {
    const lat = parseFloat(l.lat);
    const lng = parseFloat(l.lng ?? l.lon);
    return !(Number.isFinite(lat) && Number.isFinite(lng));
  }).slice(0, maxCount);

  const queryCache = new Map();
  const BATCH = 8;
  for (let i = 0; i < needGeo.length; i += BATCH) {
    const batch = needGeo.slice(i, i + BATCH);
    await Promise.all(batch.map(async (l) => {
      const q = geocodeQueryForListing(l, city);
      if (!queryCache.has(q)) {
        queryCache.set(q, await geocodeOne(q));
      }
      const g = queryCache.get(q);
      if (g) {
        l.lat = g.lat;
        l.lng = g.lng;
      }
    }));
  }

  return listings;
}

module.exports = { geocodeOne, geocodeQueryForListing, geocodeListings };
