const express = require('express');
const https   = require('https');
const router  = express.Router();

// ── City slug map ─────────────────────────────────────────────────────────────

const CITY_SLUG = {
  chennai:         'chennai',
  coimbatore:      'coimbatore',
  madurai:         'madurai',
  tiruchirappalli: 'tiruchirappalli',
  trichy:          'tiruchirappalli',
  salem:           'salem',
  tirunelveli:     'tirunelveli',
  vellore:         'vellore',
  erode:           'erode',
  kancheepuram:    'kancheepuram',
  chengalpattu:    'chengalpattu',
  tambaram:        'chennai',
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

function fetchPage(urlStr, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlStr);
    const opts   = {
      hostname: parsed.hostname,
      path:     parsed.pathname + parsed.search,
      headers:  {
        'User-Agent':                BROWSER_UA,
        'Accept':                    'text/html,application/xhtml+xml,*/*;q=0.8',
        'Accept-Language':           'en-US,en;q=0.9',
        'Accept-Encoding':           'identity',
        'Cache-Control':             'max-age=0',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest':            'document',
        'Sec-Fetch-Mode':            'navigate',
        'Sec-Fetch-Site':            'none',
        ...extraHeaders,
      },
    };
    const req = https.get(opts, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        res.resume();
        const dest = res.headers.location.startsWith('http')
          ? res.headers.location
          : `https://${parsed.hostname}${res.headers.location}`;
        return fetchPage(dest, extraHeaders).then(resolve).catch(reject);
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8') }));
      res.on('error', reject);
    });
    req.setTimeout(30000, () => { req.destroy(); reject(new Error('Timeout')); });
    req.on('error', reject);
  });
}

// ── Parse helpers ─────────────────────────────────────────────────────────────

function toNum(v) {
  if (v == null) return 0;
  const n = parseFloat(String(v).replace(/[^0-9.]/g, ''));
  return isNaN(n) ? 0 : n;
}

function parsePrice(text) {
  if (!text) return 0;
  const s = String(text).toLowerCase();
  const n = parseFloat(s.replace(/[^0-9.]/g, '')) || 0;
  if (s.includes('cr'))  return Math.round(n * 1e7);
  if (s.includes('lac') || s.includes('lakh')) return Math.round(n * 1e5);
  return n > 10000 ? Math.round(n) : 0;
}

function mapHousingProject(p) {
  const name     = (p.projectName || p.name || p.title || '').trim();
  const locality = (p.localityName || p.locality || p.area || p.location || '').trim();
  if (!name && !locality) return null;

  const minPrice = parsePrice(p.minPrice || p.price || p.priceMin || '');
  const maxPrice = parsePrice(p.maxPrice || p.priceMax || '');
  const price    = minPrice || maxPrice;

  const area  = toNum(p.minArea || p.area || p.superBuiltUpArea || 0);
  const ppsf  = toNum(p.pricePerSqft || p.ratePerSqFt || 0) ||
                (price > 0 && area > 0 ? Math.round(price / area) : 0);

  const nameKey = (name || locality).replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30);
  const locKey  = locality.replace(/[^a-zA-Z0-9]/g, '_').slice(0, 20);

  return {
    id:            `hs_${nameKey}_${locKey}`,
    projectName:   name || locality,
    locality,
    bhkType:       p.bhkType || p.bedroomCount ? `${p.bedroomCount} BHK` : '',
    priceRupees:   price,
    pricePerSqft:  Math.round(ppsf),
    area:          Math.round(area),
    status:        p.status || p.projectStatus || 'Available',
    possession:    p.possessionDate || p.possession || 'N/A',
    completionYear: null,
    reraNo:        p.reraId || p.reraNo || '',
    lat:           toNum(p.lat || p.latitude) || null,
    lng:           toNum(p.lng || p.longitude) || null,
  };
}

function extractNextData(html) {
  const m = html.match(/<script[^>]+id="__NEXT_DATA__"[^>]*>([\s\S]+?)<\/script>/i);
  if (!m) return [];
  try {
    const root = JSON.parse(m[1]);
    const pp   = root?.props?.pageProps;
    if (!pp) return [];

    const candidates = [
      pp?.projects,
      pp?.data?.projects,
      pp?.searchResult?.projects,
      pp?.projectList,
      pp?.data?.projectList,
      pp?.listings,
      pp?.data?.listings,
      pp?.searchResult?.listings,
      pp?.searchData?.projectList,
    ];
    for (const list of candidates) {
      if (Array.isArray(list) && list.length > 0) return list;
    }
  } catch (_) {}
  return [];
}

function extractInlineJson(html) {
  for (const key of ['projects', 'projectList', 'listings', 'properties']) {
    const m = html.match(new RegExp(`"${key}"\\s*:\\s*(\\[\\{.{20,}?\\}\\])`, 's'));
    if (m) {
      try {
        const list = JSON.parse(m[1]);
        if (list.length > 0) return list;
      } catch (_) {}
    }
  }
  return [];
}

function distanceKm(lat1, lon1, lat2, lon2) {
  const R    = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a    = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Main route ────────────────────────────────────────────────────────────────
// GET /api/housing?city=Chennai&proptype=Apartment&lat=13.08&lng=80.27&radius=5

router.get('/', async (req, res) => {
  const citySlug  = normalizeCity(req.query.city);
  const userLat   = parseFloat(req.query.lat);
  const userLng   = parseFloat(req.query.lng);
  const radius    = parseFloat(req.query.radius) || null;
  const hasRadius = radius && !isNaN(userLat) && !isNaN(userLng);

  let rawItems = [];
  const errors = [];

  // ── Strategy 1: New Projects page ──────────────────────────────────────
  if (rawItems.length === 0) {
    try {
      const url = `https://housing.com/in/buy/new-projects-${citySlug}`;
      const r   = await fetchPage(url);
      if (r.status === 200) {
        rawItems = extractNextData(r.body);
        if (rawItems.length === 0) rawItems = extractInlineJson(r.body);
        if (rawItems.length === 0) errors.push(`NewProj(1): ${r.body.length}B`);
      } else { errors.push(`NewProj(1) HTTP ${r.status}`); }
    } catch (e) { errors.push(`NewProj(1): ${e.message}`); }
  }

  // ── Strategy 2: Search page ────────────────────────────────────────────
  if (rawItems.length === 0) {
    try {
      const url = `https://housing.com/in/buy/search/${citySlug}`;
      const r   = await fetchPage(url);
      if (r.status === 200) {
        rawItems = extractNextData(r.body);
        if (rawItems.length === 0) rawItems = extractInlineJson(r.body);
        if (rawItems.length === 0) errors.push(`Search(2): ${r.body.length}B`);
      } else { errors.push(`Search(2) HTTP ${r.status}`); }
    } catch (e) { errors.push(`Search(2): ${e.message}`); }
  }

  // ── Strategy 3: API endpoint ───────────────────────────────────────────
  if (rawItems.length === 0) {
    try {
      const url = `https://housing.com/api/v1/search?q=${encodeURIComponent(req.query.city || 'Chennai')}&type=project&page_size=20`;
      const r   = await fetchPage(url, { Accept: 'application/json' });
      if (r.status === 200) {
        try {
          const data = JSON.parse(r.body);
          const list = data?.data?.projects || data?.projects || data?.results || [];
          if (list.length > 0) rawItems = list;
          else errors.push(`API(3): ${r.body.length}B`);
        } catch (_) { errors.push(`API(3): parse failed`); }
      } else { errors.push(`API(3) HTTP ${r.status}`); }
    } catch (e) { errors.push(`API(3): ${e.message}`); }
  }

  if (rawItems.length === 0) {
    return res.status(502).json({
      error:   `No listings found from Housing.com for "${req.query.city}".`,
      details: errors.join(' | '),
    });
  }

  let listings = rawItems.map(p => mapHousingProject(p)).filter(Boolean);

  // Deduplicate
  const seen = new Map();
  for (const l of listings) {
    if (!seen.has(l.id)) seen.set(l.id, l);
    else if (l.priceRupees > seen.get(l.id).priceRupees) seen.set(l.id, l);
  }
  listings = [...seen.values()];

  if (hasRadius) {
    listings = listings.filter(l => {
      if (!l.lat || !l.lng) return true;
      return distanceKm(userLat, userLng, l.lat, l.lng) <= radius;
    });
  }

  res.json({ source: 'Housing.com', city: req.query.city, count: listings.length, listings });
});

module.exports = router;
