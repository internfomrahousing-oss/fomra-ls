const https = require('https');

function geocodeOne(query) {
  return new Promise((resolve) => {
    const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&limit=1&lang=en`;
    const req = https.get(url, { headers: { 'User-Agent': 'FomraLS/1.0' } }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        try {
          const d = JSON.parse(Buffer.concat(chunks).toString());
          const f = d.features?.[0];
          resolve(f ? { lat: f.geometry.coordinates[1], lng: f.geometry.coordinates[0] } : null);
        } catch {
          resolve(null);
        }
      });
      res.on('error', () => resolve(null));
    });
    req.setTimeout(6000, () => { req.destroy(); resolve(null); });
    req.on('error', () => resolve(null));
  });
}

function geocodeQueryForListing(l, city) {
  const cityNorm = (city || 'Chennai').replace(/\s+district\s*$/i, '').trim();
  const name = (l.projectName || '').trim();
  const addr = (l.locality || l.address || '').trim();
  const pin = addr.match(/\b(\d{6})\b/);
  if (pin) return `${pin[1]}, Tamil Nadu, India`;
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
  const BATCH = 5;
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
