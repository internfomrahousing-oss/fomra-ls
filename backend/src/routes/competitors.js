const express = require('express');
const magicbricksRouter = require('./magicbricks');
const ninetyNineRouter  = require('./ninetyninacres');
const housingRouter     = require('./housing');
const {
  applyRadiusFilter,
  applyNearestListings,
} = require('../lib/listingRadius');
const { geocodeListings } = require('../lib/listingGeocode');

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

function callRouterWithTimeout(subRouter, query, timeoutMs) {
  return Promise.race([
    callRouter(subRouter, query),
    new Promise((resolve) => {
      setTimeout(
        () => resolve({ statusCode: 504, data: null, error: `timeout after ${timeoutMs}ms` }),
        timeoutMs,
      );
    }),
  ]);
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
    const newScore = (item.pricePerSqft || 0) + (item.priceRupees || 0) / 1e7;
    const oldScore = (existing.pricePerSqft || 0) + (existing.priceRupees || 0) / 1e7;
    if (newScore > oldScore) merged.set(key, item);
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

function isPriced(l) {
  return (l.pricePerSqft || 0) > 0 || (l.priceRupees || 0) > 0;
}

function sortListings(listings) {
  return [...listings].sort((a, b) => {
    const ap = (a.pricePerSqft || 0) + (a.priceRupees || 0) / 1e7;
    const bp = (b.pricePerSqft || 0) + (b.priceRupees || 0) / 1e7;
    return bp - ap;
  });
}

function computePriceStats(listings) {
  const rates = [];
  for (const l of listings) {
    let ppsf = l.pricePerSqft || 0;
    if (ppsf <= 0 && (l.priceRupees || 0) > 0 && (l.area || 0) > 0) {
      ppsf = Math.round(l.priceRupees / l.area);
    }
    if (ppsf > 0) rates.push(ppsf);
  }
  if (!rates.length) return null;
  rates.sort((a, b) => a - b);
  const sum = rates.reduce((a, b) => a + b, 0);
  const mid = Math.floor(rates.length / 2);
  return {
    avgPricePerSqft: Math.round(sum / rates.length),
    medianPricePerSqft: rates.length % 2
      ? rates[mid]
      : Math.round((rates[mid - 1] + rates[mid]) / 2),
    minPricePerSqft: rates[0],
    maxPricePerSqft: rates[rates.length - 1],
    pricedCount: rates.length,
  };
}

// GET /api/competitors?city=Chennai&lat=&lng=&radius=
router.get('/', async (req, res) => {
  const query = { ...req.query };
  const { lat, lng, lon, radius } = query;
  const centerLng = lng ?? lon;
  const hasRadiusFilter = !!(lat && centerLng && radius);
  const city = query.city || 'Chennai';

  const fetchQuery = { ...query };
  delete fetchQuery.lat;
  delete fetchQuery.lng;
  delete fetchQuery.lon;
  delete fetchQuery.radius;

  const allListings = [];
  const sources = [];
  const errors = [];

  const onServerless = !!process.env.VERCEL || !!process.env.NETLIFY;
  const mbTimeoutMs = onServerless ? 95000 : 150000;
  const altTimeoutMs = onServerless ? 12000 : 35000;

  const mbQuery = hasRadiusFilter
    ? { ...fetchQuery, lat, lng: centerLng, radius }
    : fetchQuery;

  const mbResult = await callRouterWithTimeout(magicbricksRouter, mbQuery, mbTimeoutMs);

  const altResults = onServerless
    ? []
    : await Promise.all([
        callRouterWithTimeout(ninetyNineRouter, fetchQuery, altTimeoutMs),
        callRouterWithTimeout(housingRouter, fetchQuery, altTimeoutMs),
      ]);

  const naResult = altResults[0] || { statusCode: 504, data: null, error: 'skipped on serverless' };
  const hoResult = altResults[1] || { statusCode: 504, data: null, error: 'skipped on serverless' };

  ingestBatch({ status: 'fulfilled', value: mbResult }, 'MagicBricks', allListings, sources, errors);
  ingestBatch({ status: 'fulfilled', value: naResult }, '99acres', allListings, sources, errors);
  ingestBatch({ status: 'fulfilled', value: hoResult }, 'Housing.com', allListings, sources, errors);

  if (allListings.length === 0) {
    return res.status(502).json({
      error: hasRadiusFilter
        ? `No competitor projects within ${radius}km of this point. Try 10km radius.`
        : `No competitor projects found for "${city}".`,
      details: errors.join(' | '),
    });
  }

  let listings = dedupeListings(allListings);
  let radiusNote = mbResult.data?.radiusNote;
  const pricedAll = listings.filter(isPriced);

  if (hasRadiusFilter) {
    const mbPriced = mbResult.statusCode === 200
      ? dedupeListings((mbResult.data?.listings || []).filter(isPriced))
      : [];

    // MagicBricks already applies radius / nearest-priced fallback — trust it when priced.
    if (mbPriced.length > 0) {
      listings = sortListings(mbPriced).slice(0, 30);
      radiusNote = mbResult.data?.radiusNote || radiusNote;
    } else {
      const latN = parseFloat(lat);
      const lngN = parseFloat(centerLng);
      const rKm = parseFloat(radius);

      await geocodeListings(listings, city, onServerless ? 20 : 80);

      const pool = pricedAll.length > 0 ? pricedAll : listings;
      const filtered = applyRadiusFilter(pool, latN, lngN, rKm);
      const pricedInRadius = filtered.listings.filter(isPriced);

      if (pricedInRadius.length >= 3) {
        listings = sortListings(pricedInRadius).slice(0, 30);
        radiusNote = filtered.radiusNote;
      } else if (pricedAll.length > 0) {
        listings = applyNearestListings(pricedAll, latN, lngN, 30);
        radiusNote =
          pricedInRadius.length > 0
            ? `Showing nearest priced projects (${listings.length} found; only ${pricedInRadius.length} strictly within ${rKm}km).`
            : `Showing nearest priced projects (${listings.length} found; none strictly within ${rKm}km).`;
      } else if (filtered.listings.length > 0) {
        listings = filtered.listings.slice(0, 30);
        radiusNote =
          filtered.radiusNote
          || 'RERA projects in radius — online prices not available for these listings.';
      } else {
        listings = applyNearestListings(listings, latN, lngN, 20);
        radiusNote =
          listings.length > 0
            ? `Showing nearest projects (${listings.length}); price data may be limited.`
            : filtered.radiusNote;
      }
    }
  } else if (pricedAll.length > 0) {
    listings = sortListings(pricedAll);
    if (listings.length > 50) {
      listings = listings.slice(0, 50);
      radiusNote = 'Showing top 50 priced city projects.';
    }
  } else if (listings.length > 50) {
    listings = sortListings(listings).slice(0, 50);
    radiusNote = 'Showing top 50 city projects. Tap the map for radius-filtered results.';
  }

  res.json({
    source:  sources.join(' + '),
    sources,
    city,
    count:   listings.length,
    radiusKm: radius ? parseFloat(radius) : null,
    center:  (lat && centerLng) ? { lat: parseFloat(lat), lng: parseFloat(centerLng) } : null,
    radiusNote,
    radiusApplied: hasRadiusFilter,
    priceStats: computePriceStats(listings),
    listings,
    partial: errors.length > 0 ? errors : undefined,
  });
});

module.exports = router;
