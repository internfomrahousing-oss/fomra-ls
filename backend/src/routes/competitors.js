const express = require('express');
const magicbricksRouter = require('./magicbricks');
const ninetyNineRouter  = require('./ninetyninacres');
const housingRouter     = require('./housing');
const squareYardsRouter = require('./squareyards');
const { applyRadiusFilter } = require('../lib/listingRadius');
const { geocodeListings } = require('../lib/listingGeocode');

const router = express.Router();

function callRouter(subRouter, query, path = '/') {
  return new Promise((resolve) => {
    const req = {
      method:  'GET',
      url:     path,
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

function callRouterWithTimeout(subRouter, query, timeoutMs, path = '/') {
  return Promise.race([
    callRouter(subRouter, query, path),
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

  const radiusQuery = hasRadiusFilter
    ? { ...fetchQuery, lat, lng: centerLng, radius }
    : fetchQuery;

  // SquareYards is reachable from datacenter/serverless IPs and returns priced
  // projects with map coordinates — it is the primary competitor source.
  // TNRERA is intentionally NOT used here: it only yields registered (unpriced)
  // projects, and this endpoint shows only priced projects within the radius.
  const syTimeoutMs = onServerless ? 20000 : 35000;
  const [mbResult, syResult] = await Promise.all([
    callRouterWithTimeout(magicbricksRouter, radiusQuery, mbTimeoutMs),
    callRouterWithTimeout(squareYardsRouter, radiusQuery, syTimeoutMs),
  ]);

  // 99acres and Housing.com hard-block datacenter IPs (HTTP 403/406) so they
  // return nothing from Vercel; only attempt them off-serverless where the
  // request originates from a residential-style IP.
  const altResults = onServerless
    ? []
    : await Promise.all([
        callRouterWithTimeout(ninetyNineRouter, fetchQuery, altTimeoutMs),
        callRouterWithTimeout(housingRouter, fetchQuery, altTimeoutMs),
      ]);

  const naResult = altResults[0] || { statusCode: 504, data: null, error: 'skipped on serverless' };
  const hoResult = altResults[1] || { statusCode: 504, data: null, error: 'skipped on serverless' };

  ingestBatch({ status: 'fulfilled', value: syResult }, 'SquareYards', allListings, sources, errors);
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

  // Only priced projects are shown — drop registered/unpriced entries entirely.
  let listings = dedupeListings(allListings).filter(isPriced);
  let radiusNote;

  if (listings.length === 0) {
    return res.status(502).json({
      error: hasRadiusFilter
        ? `No priced competitor projects within ${radius}km of this point. Try a larger radius.`
        : `No priced competitor projects found for "${city}".`,
      details: errors.join(' | '),
    });
  }

  if (hasRadiusFilter) {
    const latN = parseFloat(lat);
    const lngN = parseFloat(centerLng);
    const rKm  = parseFloat(radius);

    // Geocode the few priced listings that lack coords so they can be radius-tested.
    await geocodeListings(listings, city, onServerless ? 40 : 100);

    // Strictly inside the selected radius — no nearest-project fallback.
    const filtered = applyRadiusFilter(listings, latN, lngN, rKm);
    listings = filtered.listings.slice(0, 40);          // distance-sorted, has distanceKm

    if (listings.length === 0) {
      return res.status(502).json({
        error: `No priced competitor projects within ${rKm}km of this point. Try a larger radius.`,
        details: errors.join(' | '),
      });
    }
  } else {
    listings = sortListings(listings).slice(0, 50);
    if (listings.length === 50) radiusNote = 'Showing top 50 priced city projects.';
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
