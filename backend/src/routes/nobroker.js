const express = require('express');
const https   = require('https');
const { applyRadiusFilter } = require('../lib/listingRadius');
const router  = express.Router();

// NoBroker exposes a public buy-listing API that (unlike Housing/99acres/MB) is
// reachable from datacenter IPs. It takes a base64 searchParam carrying the
// search centre (lat/lon) + radius and returns priced resale homes with coords.
const NB_API = 'https://www.nobroker.in/api/v3/multi/property/BUY/filter';

const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

// City centres — used only when the caller doesn't pin a map point.
const CITY_CENTER = {
  chennai:         { lat: 13.0827, lon: 80.2707 },
  coimbatore:      { lat: 11.0168, lon: 76.9558 },
  madurai:         { lat: 9.9252,  lon: 78.1198 },
  tiruchirappalli: { lat: 10.7905, lon: 78.7047 },
  trichy:          { lat: 10.7905, lon: 78.7047 },
  salem:           { lat: 11.6643, lon: 78.1460 },
  tirunelveli:     { lat: 8.7139,  lon: 77.7567 },
  vellore:         { lat: 12.9165, lon: 79.1325 },
  erode:           { lat: 11.3410, lon: 77.7172 },
  kancheepuram:    { lat: 12.8342, lon: 79.7036 },
  chengalpattu:    { lat: 12.6819, lon: 79.9888 },
  tambaram:        { lat: 12.9249, lon: 80.1000 },
  pondicherry:     { lat: 11.9416, lon: 79.8083 },
  puducherry:      { lat: 11.9416, lon: 79.8083 },
  thanjavur:       { lat: 10.7870, lon: 79.1378 },
  thoothukudi:     { lat: 8.7642,  lon: 78.1348 },
  namakkal:        { lat: 11.2189, lon: 78.1674 },
  dharmapuri:      { lat: 12.1211, lon: 78.1583 },
  dindigul:        { lat: 10.3624, lon: 77.9695 },
  krishnagiri:     { lat: 12.5186, lon: 78.2137 },
};

function normalizeCity(input) {
  if (!input) return 'chennai';
  return input.toLowerCase()
    .replace(/\s*district\s*$/i, '')
    .replace(/\s+dt\s*$/i, '')
    .trim();
}

function fetchJson(urlStr, timeoutMs = 20000) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const req = https.get({
      hostname: u.hostname,
      path:     u.pathname + u.search,
      headers: {
        'User-Agent':      BROWSER_UA,
        'Accept':          'application/json, text/plain, */*',
        'Accept-Language': 'en-IN,en;q=0.9',
        'Accept-Encoding': 'identity',
        'Referer':         'https://www.nobroker.in/property/sale/chennai',
      },
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: JSON.parse(Buffer.concat(chunks).toString('utf8')) });
        } catch (_) {
          resolve({ status: res.statusCode, json: null });
        }
      });
    });
    req.setTimeout(timeoutMs, () => { req.destroy(); reject(new Error('NoBroker request timed out')); });
    req.on('error', reject);
  });
}

function buildSearchParam(lat, lon, placeName) {
  const payload = [{ lat, lon, placeId: '', placeName: placeName || '', showMap: true }];
  return encodeURIComponent(Buffer.from(JSON.stringify(payload)).toString('base64'));
}

function toNum(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function mapProperty(p) {
  const price = toNum(p.price);
  // Prefer carpet area; fall back to super-built-up (propertySize).
  const area  = toNum(p.carpetArea) > 0 ? toNum(p.carpetArea) : toNum(p.propertySize);
  const ppsf  = price > 0 && area > 0 ? Math.round(price / area) : 0;
  const bhkM  = String(p.type || '').match(/BHK\s*(\d+)/i);
  const bhk   = bhkM ? `${bhkM[1]} BHK` : '';
  const title = p.propertyTitle || p.title || p.society || 'NoBroker listing';
  const isPlot = /\b(plot|plots|land|residential\s*land)\b/i.test(title)
    || /plot|land/i.test(String(p.typeDesc || ''));

  return {
    id:             `nb_${p.id || p.propertyCode || Math.random().toString(36).slice(2)}`,
    projectName:    title,
    locality:       String(p.locality || '').trim(),
    bhkType:        bhk,
    priceRupees:    price,
    pricePerSqft:   ppsf,
    area:           Math.round(area),
    status:         'Resale',
    possession:     'N/A',
    completionYear: null,
    reraNo:         '',
    developer:      String(p.society || '').trim(),
    projectType:    isPlot ? 'Layout' : 'Building',
    registeredYear: null,
    lat:            Number.isFinite(Number(p.latitude))  ? Number(p.latitude)  : null,
    lng:            Number.isFinite(Number(p.longitude)) ? Number(p.longitude) : null,
    detailUrl:      p.detailUrl
      ? `https://www.nobroker.in${p.detailUrl}`
      : (p.shortUrl || ''),
    source:         'NoBroker',
  };
}

// GET /api/nobroker?city=Chennai&lat=&lng=&radius=
router.get('/', async (req, res) => {
  const citySlug  = normalizeCity(req.query.city);
  const userLat   = parseFloat(req.query.lat);
  const userLng   = parseFloat(req.query.lng ?? req.query.lon);
  const radius    = parseFloat(req.query.radius) || null;
  const hasPin    = Number.isFinite(userLat) && Number.isFinite(userLng);
  const center    = hasPin
    ? { lat: userLat, lon: userLng }
    : (CITY_CENTER[citySlug] || CITY_CENTER.chennai);

  const sp = buildSearchParam(center.lat, center.lon, req.query.city || citySlug);
  // Give NoBroker a generous radius; the aggregator/here re-applies the strict one.
  const nbRadius = radius && radius > 0 ? Math.max(radius, 3) : 8;
  const url = `${NB_API}?searchParam=${sp}&radius=${nbRadius}&sortBy=nbRank&pageNo=1&pageSize=100`;

  let result;
  try {
    result = await fetchJson(url);
  } catch (err) {
    return res.status(502).json({ error: `NoBroker unreachable: ${err.message}` });
  }
  if (result.status !== 200 || !result.json) {
    return res.status(502).json({ error: `NoBroker returned HTTP ${result.status}` });
  }
  if (result.json.status !== 'success' || !Array.isArray(result.json.data)) {
    return res.status(502).json({
      error: result.json.error_message || 'No NoBroker listings for this location.',
    });
  }

  let listings = result.json.data.map(mapProperty).filter((l) => l.priceRupees > 0);

  if (hasPin && radius) {
    const filtered = applyRadiusFilter(listings, userLat, userLng, radius);
    listings = filtered.listings;
  }

  listings = listings
    .sort((a, b) => {
      if (a.distanceKm != null && b.distanceKm != null) return a.distanceKm - b.distanceKm;
      return (b.pricePerSqft || 0) - (a.pricePerSqft || 0);
    })
    .slice(0, 50);

  if (listings.length === 0) {
    return res.status(502).json({
      error: `No priced NoBroker listings ${radius ? `within ${radius}km` : `for "${req.query.city || citySlug}"`}.`,
    });
  }

  res.json({
    source:        'NoBroker',
    city:          req.query.city || citySlug,
    count:         listings.length,
    listings,
    radiusApplied: !!(hasPin && radius),
  });
});

module.exports = router;
