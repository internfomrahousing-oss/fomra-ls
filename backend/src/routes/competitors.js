const express = require('express');
const magicbricksRouter = require('./magicbricks');
const ninetyNineRouter  = require('./ninetyninacres');
const housingRouter     = require('./housing');

const router = express.Router();

function callRouter(subRouter, query) {
  return new Promise((resolve) => {
    const req = {
      method:  'GET',
      url:     '/',
      query,
      params:  {},
      headers: {},
    };
    let statusCode = 200;
    let settled = false;
    const res = {
      status(c) { statusCode = c; return this; },
      setHeader() { return this; },
      json(data) {
        if (!settled) { settled = true; resolve({ statusCode, data }); }
      },
    };
    subRouter.handle(req, res, (err) => {
      if (!settled) {
        settled = true;
        resolve({ statusCode: err ? 500 : 404, data: null, error: err?.message });
      }
    });
  });
}

function dedupeListings(listings) {
  const merged = new Map();
  for (const item of listings) {
    const name = (item.projectName || '').toLowerCase().trim();
    const loc  = (item.locality || '').toLowerCase().trim();
    const key  = `${name}__${loc}`;
    if (!name && !loc) continue;

    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, item);
      continue;
    }
    const newPpsf = item.pricePerSqft || 0;
    const oldPpsf = existing.pricePerSqft || 0;
    if (newPpsf > oldPpsf || (oldPpsf === 0 && newPpsf > 0)) {
      merged.set(key, item);
    }
  }
  return [...merged.values()].sort((a, b) => {
    const ap = a.pricePerSqft || 0;
    const bp = b.pricePerSqft || 0;
    if (ap === 0 && bp === 0) return 0;
    if (ap === 0) return 1;
    if (bp === 0) return -1;
    return bp - ap;
  });
}

function ingestBatch(result, defaultSource, allListings, sources, errors) {
  if (result.status !== 'fulfilled') {
    errors.push(`${defaultSource}: ${result.reason?.message || 'failed'}`);
    return;
  }
  const { statusCode, data, error } = result.value;
  if (statusCode !== 200 || !data?.listings?.length) {
    errors.push(`${defaultSource}: ${error || data?.error || `HTTP ${statusCode}`}`);
    return;
  }
  const src = data.source || defaultSource;
  if (!sources.includes(src)) sources.push(src);
  for (const l of data.listings) {
    allListings.push({ ...l, source: l.source || src });
  }
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const p = Math.PI / 180;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2
    + Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 6371 * 2 * Math.asin(Math.sqrt(Math.max(0, a)));
}

/** Keep only projects with coordinates inside radiusKm of lat/lng. */
function filterListingsByRadius(listings, lat, lng, radiusKm) {
  const latN = parseFloat(lat);
  const lngN = parseFloat(lng);
  const r = parseFloat(radiusKm);
  if (!Number.isFinite(latN) || !Number.isFinite(lngN) || !Number.isFinite(r) || r <= 0) {
    return listings;
  }
  return listings
    .map((l) => {
      const plat = parseFloat(l.lat);
      const plng = parseFloat(l.lng ?? l.lon);
      if (!Number.isFinite(plat) || !Number.isFinite(plng)) return null;
      const dist = haversineKm(latN, lngN, plat, plng);
      return { ...l, distanceKm: Math.round(dist * 10) / 10 };
    })
    .filter((l) => l && l.distanceKm <= r)
    .sort((a, b) => (a.distanceKm || 0) - (b.distanceKm || 0));
}

// GET /api/competitors?city=Chennai
router.get('/', async (req, res) => {
  const query = { ...req.query };
  const allListings = [];
  const sources = [];
  const errors = [];

  // MagicBricks first — slowest but most reliable for priced data locally
  const mbResult = await Promise.resolve(callRouter(magicbricksRouter, query));
  ingestBatch({ status: 'fulfilled', value: mbResult }, 'MagicBricks', allListings, sources, errors);

  const hasPriced = allListings.some((l) => (l.pricePerSqft || 0) > 0 || (l.priceRupees || 0) > 0);

  // Only hit blocked portals when MagicBricks returned nothing useful
  if (!hasPriced) {
    const [naResult, hoResult] = await Promise.allSettled([
      callRouter(ninetyNineRouter, query),
      callRouter(housingRouter, query),
    ]);
    ingestBatch(naResult, '99acres', allListings, sources, errors);
    ingestBatch(hoResult, 'Housing.com', allListings, sources, errors);
  }

  if (allListings.length === 0) {
    return res.status(502).json({
      error:   `No competitor projects found for "${query.city || 'Chennai'}".`,
      details: errors.join(' | '),
    });
  }

  let listings = dedupeListings(allListings);

  const { lat, lng, lon, radius } = query;
  const centerLng = lng ?? lon;
  if (lat && centerLng && radius) {
    listings = filterListingsByRadius(listings, lat, centerLng, radius);
  }

  res.json({
    source:  sources.join(' + '),
    sources,
    city:    query.city || 'Chennai',
    count:   listings.length,
    radiusKm: radius ? parseFloat(radius) : null,
    center:  (lat && centerLng) ? { lat: parseFloat(lat), lng: parseFloat(centerLng) } : null,
    listings,
    partial: errors.length > 0 ? errors : undefined,
  });
});

module.exports = router;
