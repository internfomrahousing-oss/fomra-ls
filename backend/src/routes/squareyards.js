const express = require('express');
const https   = require('https');
const { applyRadiusFilter, applyNearestListings } = require('../lib/listingRadius');
const router  = express.Router();

// ── City slug map ─────────────────────────────────────────────────────────────
// SquareYards new-project pages live at /new-projects-in-<citySlug>

const CITY_SLUG = {
  chennai:         'chennai',
  coimbatore:      'coimbatore',
  madurai:         'madurai',
  tiruchirappalli: 'trichy',
  trichy:          'trichy',
  salem:           'salem',
  tirunelveli:     'tirunelveli',
  vellore:         'vellore',
  erode:           'erode',
  kancheepuram:    'chennai',
  kanchipuram:     'chennai',
  chengalpattu:    'chennai',
  tambaram:        'chennai',
  avadi:           'chennai',
  pondicherry:     'pondicherry',
  puducherry:      'pondicherry',
  thanjavur:       'thanjavur',
  thoothukudi:     'tuticorin',
  namakkal:        'namakkal',
  dharmapuri:      'dharmapuri',
  dindigul:        'dindigul',
  krishnagiri:     'krishnagiri',
};

function normalizeCity(input) {
  if (!input) return 'chennai';
  const clean = input.toLowerCase()
    .replace(/\s*district\s*$/i, '')
    .replace(/\s+dt\s*$/i, '')
    .trim();
  return CITY_SLUG[clean] || clean.replace(/\s+/g, '-');
}

// ── HTTP helper ───────────────────────────────────────────────────────────────

const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

function fetchPage(urlStr, timeoutMs = 20000) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlStr);
    const req = https.get({
      hostname: parsed.hostname,
      path:     parsed.pathname + parsed.search,
      headers: {
        'User-Agent':      BROWSER_UA,
        'Accept':          'text/html,application/xhtml+xml,*/*;q=0.8',
        'Accept-Language': 'en-IN,en;q=0.9',
        'Accept-Encoding': 'identity',
      },
    }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        res.resume();
        const next = res.headers.location.startsWith('http')
          ? res.headers.location
          : `https://${parsed.hostname}${res.headers.location}`;
        return fetchPage(next, timeoutMs).then(resolve).catch(reject);
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8') }));
      res.on('error', reject);
    });
    req.setTimeout(timeoutMs, () => { req.destroy(); reject(new Error('Timeout')); });
    req.on('error', reject);
  });
}

// ── Parse helpers ───────────────────────────────────────────────────────────────

// Read a data-* attribute out of a single tag string (tolerates spaces around "=")
function attr(tag, key) {
  const m = tag.match(new RegExp('data-' + key + '\\s*=\\s*"([^"]*)"', 'i'));
  return m ? m[1].trim() : '';
}

function toNum(v) {
  const n = parseFloat(String(v || 0).replace(/[^0-9.]/g, ''));
  return isNaN(n) ? 0 : n;
}

function projectIdFromUrl(url) {
  const m = (url || '').match(/\/(\d+)\/project/);
  return m ? m[1] : '';
}

// Each project card carries two data-rich tags:
//   <span class="map-cta" data-lat data-long data-url …>       → coordinates
//   <li class="… charges-popup-btn" data-prjid data-prjname …> → price / area / config
function parseProjects(html) {
  // 1) coordinates keyed by project id
  const geo = {};
  for (const m of html.matchAll(/<[^>]*class="[^"]*map-cta[^"]*"[^>]*>/gi)) {
    const tag = m[0];
    const id  = projectIdFromUrl(attr(tag, 'url'));
    if (!id) continue;
    const lat = parseFloat(attr(tag, 'lat'));
    const lng = parseFloat(attr(tag, 'long'));
    if (Number.isFinite(lat) && Number.isFinite(lng)) geo[id] = { lat, lng };
  }

  // 2) project details from the charges popup button
  const out = [];
  const seen = new Set();
  for (const m of html.matchAll(/<li[^>]*charges-popup-btn[^>]*>/gi)) {
    const tag = m[0];
    const id  = attr(tag, 'prjid');
    if (!id || seen.has(id)) continue;
    seen.add(id);

    const name    = attr(tag, 'prjname');
    if (!name) continue;
    const low     = toNum(attr(tag, 'lowcost'));
    const minArea = toNum(attr(tag, 'minarea'));
    const ppsf    = low > 0 && minArea > 0 ? Math.round(low / minArea) : 0;
    const units   = attr(tag, 'prjunits');            // e.g. "2 BHK-3 BHK"
    const bhk     = units ? units.split('-')[0].trim() : '';
    const status  = attr(tag, 'propstatus') || 'Available';
    const locality = attr(tag, 'sublocation') || attr(tag, 'location');
    const coord   = geo[id] || {};

    out.push({
      id:             `sy_${id}`,
      projectName:    name,
      locality,
      bhkType:        bhk,
      priceRupees:    Math.round(low),
      pricePerSqft:   ppsf,
      area:           Math.round(minArea),
      status:         /under\s*construction/i.test(status) ? 'Under Construction' : status,
      possession:     'N/A',
      completionYear: null,
      reraNo:         '',
      developer:      attr(tag, 'developer'),
      projectType:    'Building',
      registeredYear: null,
      lat:            coord.lat ?? null,
      lng:            coord.lng ?? null,
      detailUrl:      attr(tag, 'baseurl') && attr(tag, 'url')
        ? `https://www.squareyards.com/${attr(tag, 'url')}`
        : '',
      source:         'SquareYards',
    });
  }
  return out;
}

// ── GET /api/squareyards?city=Chennai&lat=&lng=&radius= ─────────────────────────

router.get('/', async (req, res) => {
  const citySlug  = normalizeCity(req.query.city);
  const userLat   = parseFloat(req.query.lat);
  const userLng   = parseFloat(req.query.lng);
  const radius    = parseFloat(req.query.radius) || null;
  const hasRadius = radius && !isNaN(userLat) && !isNaN(userLng);

  const errors = [];
  let listings = [];

  // New projects + ready-to-move pages both carry the same card markup.
  const pages = [
    `https://www.squareyards.com/new-projects-in-${citySlug}`,
    `https://www.squareyards.com/ready-to-move-projects-in-${citySlug}`,
  ];

  const results = await Promise.allSettled(pages.map((u) => fetchPage(u)));
  results.forEach((r, i) => {
    if (r.status === 'fulfilled' && r.value.status === 200) {
      listings.push(...parseProjects(r.value.body));
    } else {
      errors.push(`${pages[i].split('/').pop()}: ${r.reason?.message || `HTTP ${r.value?.status}`}`);
    }
  });

  // Deduplicate by id, keeping the entry with the richer price.
  const seen = new Map();
  for (const l of listings) {
    const prev = seen.get(l.id);
    if (!prev || l.priceRupees > prev.priceRupees) seen.set(l.id, l);
  }
  listings = [...seen.values()];

  if (listings.length === 0) {
    return res.status(502).json({
      error:   `No listings found from SquareYards for "${req.query.city || citySlug}".`,
      details: errors.join(' | '),
    });
  }

  let radiusNote;
  if (hasRadius) {
    const priced = listings.filter((l) => (l.priceRupees || 0) > 0 || (l.pricePerSqft || 0) > 0);
    const filtered = applyRadiusFilter(listings, userLat, userLng, radius);
    const pricedInRadius = filtered.listings.filter(
      (l) => (l.priceRupees || 0) > 0 || (l.pricePerSqft || 0) > 0,
    );

    // Prefer projects that are genuinely inside the radius — show them even if
    // there are only one or two. Only fall back to nearby projects when the
    // radius is truly empty, and clearly flag that they are outside it.
    if (pricedInRadius.length >= 1) {
      listings = pricedInRadius;
      radiusNote = filtered.radiusNote;
    } else if (priced.length > 0) {
      listings = applyNearestListings(priced, userLat, userLng, 12);
      radiusNote = `No priced projects within ${radius}km — showing the ${listings.length} nearest instead.`;
    } else {
      listings = filtered.listings.length > 0
        ? filtered.listings
        : applyNearestListings(listings, userLat, userLng, 12);
      radiusNote = filtered.radiusNote;
    }

    listings = listings
      .sort((a, b) => {
        if (a.distanceKm != null && b.distanceKm != null) return a.distanceKm - b.distanceKm;
        return (b.pricePerSqft || 0) - (a.pricePerSqft || 0);
      })
      .slice(0, 30);
  } else {
    listings = listings
      .sort((a, b) => (b.pricePerSqft || 0) - (a.pricePerSqft || 0))
      .slice(0, 50);
  }

  res.json({
    source: 'SquareYards',
    city:   req.query.city || citySlug,
    count:  listings.length,
    listings,
    radiusNote,
    radiusApplied: !!hasRadius,
  });
});

module.exports = router;
