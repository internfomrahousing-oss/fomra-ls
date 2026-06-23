const express = require('express');
const https   = require('https');
const router  = express.Router();

// ── City slug map ─────────────────────────────────────────────────────────────

const CITY_SLUG = {
  chennai:         'Chennai',
  coimbatore:      'Coimbatore',
  madurai:         'Madurai',
  tiruchirappalli: 'Tiruchirappalli',
  trichy:          'Tiruchirappalli',
  salem:           'Salem',
  tirunelveli:     'Tirunelveli',
  vellore:         'Vellore',
  erode:           'Erode',
  kancheepuram:    'Kancheepuram',
  chengalpattu:    'Chengalpattu',
  tambaram:        'Chennai',
  pondicherry:     'Pondicherry',
  puducherry:      'Pondicherry',
  thanjavur:       'Thanjavur',
  thoothukudi:     'Thoothukudi',
  namakkal:        'Namakkal',
  dharmapuri:      'Dharmapuri',
  dindigul:        'Dindigul',
  krishnagiri:     'Krishnagiri',
};

function normalizeCity(input) {
  if (!input) return 'Chennai';
  const clean = input.toLowerCase()
    .replace(/\s*district\s*$/i, '')
    .replace(/\s+dt\s*$/i, '')
    .trim();
  return CITY_SLUG[clean] || (input.charAt(0).toUpperCase() + input.slice(1).toLowerCase());
}

// ── HTTP helper ───────────────────────────────────────────────────────────────

const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

const NAV_HEADERS = {
  'User-Agent':                BROWSER_UA,
  'Accept':                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language':           'en-US,en;q=0.9',
  'Accept-Encoding':           'identity',
  'Connection':                'keep-alive',
  'Cache-Control':             'max-age=0',
  'Upgrade-Insecure-Requests': '1',
  'Sec-Fetch-Dest':            'document',
  'Sec-Fetch-Mode':            'navigate',
  'Sec-Fetch-Site':            'none',
  'Sec-Fetch-User':            '?1',
};

function fetchPage(urlStr, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlStr);
    const options = {
      hostname: parsed.hostname,
      path:     parsed.pathname + parsed.search,
      headers:  { ...NAV_HEADERS, ...extraHeaders },
    };
    const req = https.get(options, (res) => {
      // Follow redirects
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

function toNum(val) {
  if (val == null) return 0;
  if (typeof val === 'number') return val;
  const s = String(val).replace(/[^0-9.]/g, '');
  return parseFloat(s) || 0;
}

function parsePrice(p) {
  if (!p) return 0;
  const text = String(p).toLowerCase();
  const n    = parseFloat(text.replace(/[^0-9.]/g, '')) || 0;
  if (text.includes('cr'))  return Math.round(n * 1e7);
  if (text.includes('lac') || text.includes('lakh')) return Math.round(n * 1e5);
  if (n > 1000) return Math.round(n);   // already in rupees
  return 0;
}

// Parse a 99acres property object from their JSON API
function mapProperty(p, city) {
  const name      = (p.prop_name || p.society_name || p.propHeading || p.prop_heading || '').trim();
  const locality  = (p.locality_name || p.area_name || p.locality || '').trim();
  if (!name && !locality) return null;

  const rawPrice  = p.price_details?.price_in_lac
    ? `${p.price_details.price_in_lac} Lac`
    : (p.price_details?.price_in_cr ? `${p.price_details.price_in_cr} Cr` : p.price || '');

  const priceRupees   = parsePrice(rawPrice) || Math.round(toNum(p.price_in_lac) * 1e5) || Math.round(toNum(p.total_price));
  const area          = toNum(p.area_detail?.area) || toNum(p.super_area) || toNum(p.area);
  const ppsf          = toNum(p.rate?.price_per_unit_area) || toNum(p.rate_per_sqft) ||
                        (priceRupees > 0 && area > 0 ? Math.round(priceRupees / area) : 0);

  const bedroom       = p.bedroom_count || p.bedroom || p.bhk || '';
  const bhkType       = bedroom ? `${bedroom} BHK` : '';
  const status        = p.property_status || p.status || 'Available';
  const possession    = p.possession_details || p.possession || 'N/A';
  const reraNo        = p.rera_id || p.rera_no || p.rera || '';

  const nameKey = (name || locality).replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30);
  const locKey  = locality.replace(/[^a-zA-Z0-9]/g, '_').slice(0, 20);

  return {
    id:           `99_${nameKey}_${locKey}`,
    projectName:  name || locality,
    locality,
    bhkType,
    priceRupees,
    pricePerSqft: Math.round(ppsf),
    area:         Math.round(area),
    status,
    possession,
    completionYear: null,
    reraNo,
    lat: toNum(p.geo_y) || toNum(p.latitude) || null,
    lng: toNum(p.geo_x) || toNum(p.longitude) || null,
  };
}

// Extract property list from 99acres Next.js __NEXT_DATA__ embed
function extractNextData(html) {
  const m = html.match(/<script[^>]+id="__NEXT_DATA__"[^>]*>([\s\S]+?)<\/script>/i);
  if (!m) return [];
  try {
    const root = JSON.parse(m[1]);
    const pp   = root?.props?.pageProps;
    if (!pp) return [];

    // Try various known paths in 99acres Next.js structure
    const candidates = [
      pp?.data?.searchresult?.properties,
      pp?.data?.propertiesListing?.properties,
      pp?.searchResult?.properties,
      pp?.properties,
      pp?.data?.properties,
      pp?.result?.properties,
      pp?.data?.result?.properties,
    ];
    for (const list of candidates) {
      if (Array.isArray(list) && list.length > 0) return list;
    }
  } catch (_) {}
  return [];
}

// Extract from inline JSON snippets as a fallback
function extractInlineJson(html) {
  for (const key of ['properties', 'resultList', 'propertyList']) {
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

// ── Haversine ─────────────────────────────────────────────────────────────────

function distanceKm(lat1, lon1, lat2, lon2) {
  const R    = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a    = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Main route ────────────────────────────────────────────────────────────────
// GET /api/99acres?city=Chennai&proptype=Apartment&lat=13.08&lng=80.27&radius=5

router.get('/', async (req, res) => {
  const city      = normalizeCity(req.query.city);
  const proptype  = req.query.proptype || 'Apartment';
  const userLat   = parseFloat(req.query.lat);
  const userLng   = parseFloat(req.query.lng);
  const radius    = parseFloat(req.query.radius) || null;
  const hasRadius = radius && !isNaN(userLat) && !isNaN(userLng);

  let rawProperties = [];
  const errors      = [];

  const cityLower = city.toLowerCase();
  const slug      = `${cityLower}-prp`;

  // ── Strategy 1: Search page (Next.js SSR with embedded JSON) ───────────
  if (rawProperties.length === 0) {
    try {
      const url = `https://www.99acres.com/search/property/buy/${slug}?preference=S&area_unit=1&res_com=R`;
      const r   = await fetchPage(url);
      if (r.status === 200) {
        rawProperties = extractNextData(r.body);
        if (rawProperties.length === 0) rawProperties = extractInlineJson(r.body);
        if (rawProperties.length === 0) errors.push(`Search(1): ${r.body.length}B`);
      } else {
        errors.push(`Search(1) HTTP ${r.status}`);
      }
    } catch (e) { errors.push(`Search(1): ${e.message}`); }
  }

  // ── Strategy 2: City landing page ─────────────────────────────────────
  if (rawProperties.length === 0) {
    try {
      const url = `https://www.99acres.com/search/property/buy/in-${cityLower}-ffid?preference=S&area_unit=1&res_com=R`;
      const r   = await fetchPage(url);
      if (r.status === 200) {
        rawProperties = extractNextData(r.body);
        if (rawProperties.length === 0) rawProperties = extractInlineJson(r.body);
        if (rawProperties.length === 0) errors.push(`Landing(2): ${r.body.length}B`);
      } else {
        errors.push(`Landing(2) HTTP ${r.status}`);
      }
    } catch (e) { errors.push(`Landing(2): ${e.message}`); }
  }

  // ── Strategy 3: Apartment-specific search ────────────────────────────
  if (rawProperties.length === 0) {
    try {
      const typeMap = {
        'Apartment': 'multistorey-apartment',
        'Villa':     'villa-independent-house',
        'Plot':      'residential-plot',
        'Commercial':'commercial-office-space',
        'All':       'multistorey-apartment',
      };
      const typeSlug = typeMap[proptype] || 'multistorey-apartment';
      const url = `https://www.99acres.com/search/property/buy/${typeSlug}-in-${cityLower}-ffid?preference=S&area_unit=1&res_com=R`;
      const r   = await fetchPage(url);
      if (r.status === 200) {
        rawProperties = extractNextData(r.body);
        if (rawProperties.length === 0) rawProperties = extractInlineJson(r.body);
        if (rawProperties.length === 0) errors.push(`TypeSearch(3): ${r.body.length}B`);
      } else {
        errors.push(`TypeSearch(3) HTTP ${r.status}`);
      }
    } catch (e) { errors.push(`TypeSearch(3): ${e.message}`); }
  }

  if (rawProperties.length === 0) {
    return res.status(502).json({
      error:   `No listings found from 99acres for "${city}".`,
      details: errors.join(' | '),
    });
  }

  // ── Map to standard format ────────────────────────────────────────────
  let listings = rawProperties
    .map(p => mapProperty(p, city))
    .filter(Boolean);

  // Deduplicate
  const seen = new Map();
  for (const l of listings) {
    if (!seen.has(l.id)) seen.set(l.id, l);
    else if (l.priceRupees > seen.get(l.id).priceRupees) seen.set(l.id, l);
  }
  listings = [...seen.values()];

  // Optional radius filter
  if (hasRadius) {
    listings = listings.filter(l => {
      if (!l.lat || !l.lng) return true;
      return distanceKm(userLat, userLng, l.lat, l.lng) <= radius;
    });
  }

  res.json({ source: '99acres', city, count: listings.length, listings });
});

module.exports = router;
