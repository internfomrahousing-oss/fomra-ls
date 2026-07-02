const express = require('express');
const magicbricksRouter = require('./magicbricks');
const ninetyNineRouter  = require('./ninetyninacres');
const housingRouter     = require('./housing');
const squareYardsRouter = require('./squareyards');
const tnreraRouter      = require('./tnrera');
const {
  applyRadiusFilter,
  applyNearestListings,
} = require('../lib/listingRadius');
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

// TNRERA /projects returns a bare array of registered projects (no price/coords).
// Map them into the listing shape so they broaden coverage beyond SquareYards.
function ingestTnrera(result, allListings, sources, errors) {
  if (result.status !== 'fulfilled') {
    errors.push(`TNRERA: ${result.reason?.message || 'failed'}`);
    return;
  }
  const { statusCode, data, error } = result.value;
  const rows = Array.isArray(data) ? data : (data?.listings || null);
  if (statusCode !== 200 || !rows?.length) {
    errors.push(`TNRERA: ${error || data?.error || `HTTP ${statusCode}`}`);
    return;
  }
  if (!sources.includes('TNRERA')) sources.push('TNRERA');
  for (const r of rows) {
    const key = (r.reraNo || r.projectName || '').replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30);
    const yearM = String(r.reraNo || '').match(/(20\d{2})\s*$/);
    allListings.push({
      id:             r.id || `rera_${key}`,
      projectName:    r.projectName || r.reraNo || 'RERA Project',
      locality:       '',
      developer:      r.developer || '',
      reraNo:         r.reraNo || '',
      status:         r.status || 'Registered',
      priceRupees:    0,
      pricePerSqft:   0,
      area:           0,
      lat:            null,
      lng:            null,
      projectType:    r.projectType || 'Building',
      registeredYear: r.registeredYear ?? (yearM ? parseInt(yearM[1], 10) : null),
      source:         'TNRERA',
    });
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
  // TNRERA (official Tamil Nadu RERA registry) is reachable from serverless IPs
  // and adds many registered projects that SquareYards alone misses.
  const syTimeoutMs = onServerless ? 20000 : 35000;
  const reraTimeoutMs = onServerless ? 30000 : 40000;
  const [mbResult, syResult, reraResult] = await Promise.all([
    callRouterWithTimeout(magicbricksRouter, radiusQuery, mbTimeoutMs),
    callRouterWithTimeout(squareYardsRouter, radiusQuery, syTimeoutMs),
    callRouterWithTimeout(tnreraRouter, { district: city }, reraTimeoutMs, '/projects'),
  ]);

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
  ingestTnrera({ status: 'fulfilled', value: reraResult }, allListings, sources, errors);
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
    const latN = parseFloat(lat);
    const lngN = parseFloat(centerLng);
    const rKm  = parseFloat(radius);

    // The fast primary sources (SquareYards, MagicBricks) already return coords;
    // other sources (TNRERA) don't, so geocode the coordinate-less ones and let
    // every source with a resolved position take part in the radius filter.
    await geocodeListings(listings, city, onServerless ? 40 : 100);
    const hasCoords = (l) => {
      const la = parseFloat(l.lat);
      const lo = parseFloat(l.lng ?? l.lon);
      return Number.isFinite(la) && Number.isFinite(lo);
    };
    let pool = listings.filter(hasCoords);
    if (pool.length === 0) pool = listings;

    // The aggregator is authoritative about the radius: re-apply it here rather
    // than trusting each sub-router's own nearest-project fallback. Filter the
    // full pool (priced + registered) so every in-radius project can be shown.
    const pricedPool = pool.filter(isPriced);
    const filtered = applyRadiusFilter(pool, latN, lngN, rKm);
    const inRadius = filtered.listings;                 // distance-sorted, has distanceKm
    const pricedInRadius = inRadius.filter(isPriced);
    const unpricedInRadius = inRadius.filter((l) => !isPriced(l));

    if (pricedInRadius.length >= 1) {
      // Priced projects first, then registered projects (e.g. TNRERA) also inside
      // the radius — so results aren't limited to the handful of priced ones.
      listings = [...pricedInRadius, ...unpricedInRadius].slice(0, 40);
      radiusNote = unpricedInRadius.length
        ? 'Priced projects first; registered projects (e.g. TNRERA) shown with approximate location.'
        : undefined;
    } else if (inRadius.length > 0) {
      listings = inRadius.slice(0, 40);
      radiusNote = 'Projects within radius — online prices unavailable for these.';
    } else {
      // Nothing inside the radius: show only a few nearest, clearly flagged.
      listings = applyNearestListings(pricedPool.length ? pricedPool : pool, latN, lngN, 12);
      radiusNote = listings.length
        ? `No projects within ${rKm}km — showing the ${listings.length} nearest instead.`
        : `No competitor projects near this point. Try a larger radius.`;
    }
  } else if (pricedAll.length > 0) {
    // Priced projects first, then registered/unpriced ones (TNRERA etc.) so the
    // city list is as complete as possible instead of dropping unpriced projects.
    const unpriced = listings.filter((l) => !isPriced(l));
    listings = [...sortListings(pricedAll), ...unpriced];
    if (listings.length > 50) {
      listings = listings.slice(0, 50);
      radiusNote = 'Showing top 50 city projects (priced first).';
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
