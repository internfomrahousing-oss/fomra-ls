const express = require('express');
const https   = require('https');
const http    = require('http');
const router  = express.Router();

// ── City map ──────────────────────────────────────────────────────────────────

const CITY_MAP = {
  'chennai': 'Chennai', 'coimbatore': 'Coimbatore', 'madurai': 'Madurai',
  'tiruchirappalli': 'Tiruchirappalli', 'trichy': 'Tiruchirappalli',
  'salem': 'Salem', 'tirunelveli': 'Tirunelveli', 'vellore': 'Vellore',
  'erode': 'Erode', 'kancheepuram': 'Kancheepuram',
  'chengalpattu': 'Chennai', 'tambaram': 'Chennai', 'avadi': 'Chennai',
  'pondicherry': 'Pondicherry', 'puducherry': 'Pondicherry',
  'thanjavur': 'Thanjavur', 'thoothukudi': 'Thoothukudi',
  'namakkal': 'Namakkal', 'dharmapuri': 'Dharmapuri',
  'dindigul': 'Dindigul', 'krishnagiri': 'Krishnagiri',
};

const PROP_TYPE_MAP = {
  'Apartment': 'Multistorey-Apartment,Builder-Floor-Apartment,Penthouse,Studio-Apartment',
  'Villa':     'Villa,Independent-House',
  'Plot':      'Residential-Plot',
  'Commercial':'Commercial-Office-Space,Shop-Showroom',
  'All':       'Multistorey-Apartment,Builder-Floor-Apartment,Villa,Independent-House,Residential-Plot',
};

function normalizeCity(input) {
  if (!input) return 'Chennai';
  const lower = input.toLowerCase()
    .replace(/\s*district\s*$/i, '').replace(/\s+dt\s*$/i, '').trim();
  return CITY_MAP[lower] || input.replace(/\s+District$/i, '').trim();
}

// ── HTTP helper ────────────────────────────────────────────────────────────────

function fetchRaw(urlStr, headers, timeoutMs = 25000) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlStr);
    const lib    = parsed.protocol === 'https:' ? https : http;
    const req    = lib.get(
      { hostname: parsed.hostname, path: parsed.pathname + parsed.search, headers },
      (res) => {
        if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
          res.resume();
          const next = res.headers.location.startsWith('http')
            ? res.headers.location
            : `https://${parsed.hostname}${res.headers.location}`;
          return fetchRaw(next, headers, timeoutMs).then(resolve).catch(reject);
        }
        const chunks = [];
        res.on('data', c => chunks.push(c));
        res.on('end', () => resolve({
          status: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString('utf8'),
        }));
        res.on('error', reject);
      },
    );
    req.setTimeout(timeoutMs, () => { req.destroy(); reject(new Error('Timeout')); });
    req.on('error', reject);
  });
}

// ── Header profiles ────────────────────────────────────────────────────────────

// Android Dalvik — mimics OkHttp used by Android apps
const ANDROID_HEADERS = {
  'User-Agent':      'Dalvik/2.1.0 (Linux; U; Android 12; SM-S908B Build/SP1A.210812.016)',
  'Accept':          'application/json, text/plain, */*',
  'Accept-Language': 'en-IN,en;q=0.9',
  'Accept-Encoding': 'identity',
  'Connection':      'keep-alive',
};

// Mobile Chrome UA
const MOBILE_CHROME_HEADERS = {
  'User-Agent':      'Mozilla/5.0 (Linux; Android 12; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
  'Accept':          'text/html,application/xhtml+xml,*/*;q=0.8',
  'Accept-Language': 'en-IN,en;q=0.9',
  'Accept-Encoding': 'identity',
  'Connection':      'keep-alive',
};

// Minimal browser headers (no Sec-* fingerprinting)
const MINIMAL_HEADERS = {
  'User-Agent':      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  'Accept':          'application/json, text/plain, */*',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'identity',
};

// iOS app User-Agent
const IOS_HEADERS = {
  'User-Agent':      'MagicBricks/5.8 CFNetwork/1485 Darwin/23.1.0',
  'Accept':          'application/json',
  'Accept-Language': 'en-IN',
  'Accept-Encoding': 'identity',
};

// ── Parse helpers ──────────────────────────────────────────────────────────────

function stripTags(s) {
  return s.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ')
    .replace(/&#x27;/g, "'").replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim();
}

function parsePrice(text) {
  const m = text.match(/[₹Rs.]+\s*([\d.]+)\s*(Lac|Cr)/i);
  if (!m) return 0;
  const n = parseFloat(m[1]);
  return m[2].toLowerCase() === 'cr' ? Math.round(n * 1e7) : Math.round(n * 1e5);
}

function toNum(v) {
  const n = parseFloat(String(v || 0).replace(/[^0-9.]/g, ''));
  return isNaN(n) ? 0 : n;
}

function parsePossessionYear(text) {
  const short = text.match(/[''](\d{2})\b/);
  if (short) return 2000 + parseInt(short[1]);
  const full = text.match(/\b(20\d{2})\b/);
  return full ? parseInt(full[1]) : null;
}

// ── Map listing data to output format ─────────────────────────────────────────

function mapListing(p) {
  const name     = (p.projectName || p.society || p.propHeading || p.name || '').trim();
  const locality = (p.localityName || p.locality || p.area || p.location || '').trim();
  if (!name && !locality) return null;

  const price   = toNum(p.price || p.minPrice || p.totalPrice || p.startingPrice || 0);
  const area    = toNum(p.minCarpetArea || p.carpetArea || p.superArea || p.minArea || 0);
  const ppsf    = toNum(p.ratePerSqFt || p.pricePerSqft || p.rate || p.pricePerSqFeet || 0) ||
                  (price > 0 && area > 0 ? Math.round(price / area) : 0);

  const nameKey = (name || locality).replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30);
  const locKey  = locality.replace(/[^a-zA-Z0-9]/g, '_').slice(0, 20);
  const poss    = p.possessionDate || p.possession || p.readyToMove || 'N/A';

  return {
    id:             `mb_${nameKey}_${locKey}`,
    projectName:    name || locality,
    locality,
    bhkType:        p.bedroom ? `${p.bedroom} BHK` : (p.bhkType || p.roomType || ''),
    priceRupees:    Math.round(price),
    pricePerSqft:   Math.round(ppsf),
    area:           Math.round(area),
    status:         p.currentStatus || p.status || p.projectStatus || 'Available',
    possession:     typeof poss === 'string' ? poss : 'N/A',
    completionYear: null,
    reraNo:         p.reraId || p.reraNo || p.reraNumber || '',
    lat:            null,
    lng:            null,
  };
}

function parseMbJson(data) {
  const candidates = [
    data?.propertyList, data?.data?.propertyList, data?.resultList,
    data?.data?.resultList, data?.searchResult?.resultList, data?.results,
    data?.listings, data?.propList, data?.data?.results,
    data?.searchData?.resultList, data?.projectList, data?.data?.projectList,
  ];
  for (const list of candidates) {
    if (Array.isArray(list) && list.length > 0) {
      return list.map(mapListing).filter(Boolean);
    }
  }
  return [];
}

function extractEmbedded(html) {
  const nextM = html.match(/<script[^>]+id="__NEXT_DATA__"[^>]*>([\s\S]+?)<\/script>/i);
  if (nextM) {
    try {
      const data = JSON.parse(nextM[1]);
      const pp   = data?.props?.pageProps;
      if (pp) {
        let r = parseMbJson(pp);
        if (!r.length) r = parseMbJson(pp.searchResult || {});
        if (!r.length) r = parseMbJson(pp.data || {});
        if (r.length > 0) return r;
      }
    } catch (_) {}
  }
  for (const key of ['resultList', 'propertyList', 'listings', 'propList', 'projectList']) {
    const m = html.match(new RegExp(`"${key}"\\s*:\\s*(\\[\\{.{10,}?\\}\\])`, 's'));
    if (m) {
      try {
        const list = JSON.parse(m[1]);
        if (list.length > 0) return list.map(mapListing).filter(Boolean);
      } catch (_) {}
    }
  }
  return [];
}

// ── TNRERA HTML table parser (fallback source) ────────────────────────────────

function parseTnreraTable(html) {
  const rows = [];
  function stripHtml(s) {
    return s.replace(/<[^>]+>/g,' ').replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/\s+/g,' ').trim();
  }
  const thPat = /<th[^>]*>([\s\S]*?)<\/th>/gi;
  const headers = [];
  let m;
  while ((m = thPat.exec(html)) !== null) headers.push(stripHtml(m[1]).toLowerCase());
  const iReg  = headers.findIndex(h => h.includes('reg') || h.includes('rera'));
  const iName = headers.findIndex(h => h.includes('project') || h.includes('name'));
  const iDev  = headers.findIndex(h => h.includes('promot') || h.includes('developer') || h.includes('builder'));
  const iDist = headers.findIndex(h => h.includes('district'));
  const iStat = headers.findIndex(h => h.includes('status'));
  const tbodyM = html.match(/<tbody[^>]*>([\s\S]*?)<\/tbody>/i);
  if (!tbodyM) return rows;
  const rowPat = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowM;
  while ((rowM = rowPat.exec(tbodyM[1])) !== null) {
    const cellPat = /<td[^>]*>([\s\S]*?)<\/td>/gi;
    const cells = [];
    let cellM;
    while ((cellM = cellPat.exec(rowM[1])) !== null) cells.push(stripHtml(cellM[1]));
    if (cells.length < 3) continue;
    const pick = (idx) => (idx >= 0 && idx < cells.length ? cells[idx] : '') || '';
    const reraNo = pick(iReg >= 0 ? iReg : 1);
    const name   = pick(iName >= 0 ? iName : 2);
    const dev    = pick(iDev >= 0 ? iDev : 3);
    const dist   = pick(iDist >= 0 ? iDist : 4);
    const status = pick(iStat >= 0 ? iStat : 5);
    if (!name && !reraNo) continue;
    rows.push({ reraNo, projectName: name || reraNo, developer: dev, district: dist, status });
  }
  return rows;
}

// ── Geocode localities ─────────────────────────────────────────────────────────

function geocodeOne(query) {
  return new Promise((resolve) => {
    const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&limit=1&lang=en`;
    const req = https.get(url, { headers: { 'User-Agent': 'FomraLS/1.0' } }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        try {
          const d = JSON.parse(Buffer.concat(chunks).toString());
          const f = d.features?.[0];
          resolve(f ? { lat: f.geometry.coordinates[1], lng: f.geometry.coordinates[0] } : null);
        } catch { resolve(null); }
      });
      res.on('error', () => resolve(null));
    });
    req.setTimeout(8000, () => { req.destroy(); resolve(null); });
    req.on('error', () => resolve(null));
  });
}

async function geocodeLocalities(localities) {
  const unique = [...new Set(localities.filter(Boolean))];
  const cache  = {};
  const BATCH  = 4;
  for (let i = 0; i < unique.length; i += BATCH) {
    const batch   = unique.slice(i, i + BATCH);
    const results = await Promise.all(batch.map(l => geocodeOne(`${l}, India`)));
    batch.forEach((l, idx) => { if (results[idx]) cache[l] = results[idx]; });
  }
  return cache;
}

// ── Main route ────────────────────────────────────────────────────────────────
// GET /api/magicbricks?city=Chennai&proptype=Apartment

router.get('/', async (req, res) => {
  const city       = normalizeCity(req.query.city);
  const proptype   = req.query.proptype || 'Apartment';
  const mbPropType = PROP_TYPE_MAP[proptype] || PROP_TYPE_MAP['Apartment'];
  const userLat    = parseFloat(req.query.lat);
  const userLng    = parseFloat(req.query.lng);
  const radius     = parseFloat(req.query.radius) || null;
  const hasRadius  = radius && !isNaN(userLat) && !isNaN(userLng);

  let listings = [];
  const errors = [];

  const searchApiBase =
    `https://www.magicbricks.com/mbsrp/propertySearch.html` +
    `?multiLang=en&cityName=${encodeURIComponent(city)}` +
    `&proptype=${mbPropType}&pgNo=1&resi_flag=1&newPropFlag=3&type=search`;

  // ── Strategy 1: Android Dalvik UA (mimics mobile app) ──────────────────
  if (listings.length === 0) {
    try {
      const r = await fetchRaw(searchApiBase, ANDROID_HEADERS);
      if (r.status === 200) {
        const body = r.body.trim();
        if (body.startsWith('{') || body.startsWith('[')) {
          try { listings = parseMbJson(JSON.parse(body)); } catch (_) {}
        }
        if (!listings.length) listings = extractEmbedded(r.body);
        if (!listings.length) errors.push(`Android(1): ${body.length}B`);
      } else { errors.push(`Android(1) HTTP ${r.status}`); }
    } catch (e) { errors.push(`Android(1): ${e.message}`); }
  }

  // ── Strategy 2: iOS app UA ──────────────────────────────────────────────
  if (listings.length === 0) {
    try {
      const r = await fetchRaw(searchApiBase, IOS_HEADERS);
      if (r.status === 200) {
        const body = r.body.trim();
        if (body.startsWith('{') || body.startsWith('[')) {
          try { listings = parseMbJson(JSON.parse(body)); } catch (_) {}
        }
        if (!listings.length) listings = extractEmbedded(r.body);
        if (!listings.length) errors.push(`iOS(2): ${body.length}B`);
      } else { errors.push(`iOS(2) HTTP ${r.status}`); }
    } catch (e) { errors.push(`iOS(2): ${e.message}`); }
  }

  // ── Strategy 3: Minimal headers (no Sec-* fingerprinting) ──────────────
  if (listings.length === 0) {
    try {
      const r = await fetchRaw(searchApiBase, MINIMAL_HEADERS);
      if (r.status === 200) {
        const body = r.body.trim();
        if (body.startsWith('{') || body.startsWith('[')) {
          try { listings = parseMbJson(JSON.parse(body)); } catch (_) {}
        }
        if (!listings.length) listings = extractEmbedded(r.body);
        if (!listings.length) errors.push(`Minimal(3): ${body.length}B`);
      } else { errors.push(`Minimal(3) HTTP ${r.status}`); }
    } catch (e) { errors.push(`Minimal(3): ${e.message}`); }
  }

  // ── Strategy 4: Mobile site m.magicbricks.com ───────────────────────────
  if (listings.length === 0) {
    try {
      const mUrl =
        `https://m.magicbricks.com/new-projects-in-${city.toLowerCase()}-pppfsale`;
      const r = await fetchRaw(mUrl, MOBILE_CHROME_HEADERS);
      if (r.status === 200) {
        listings = extractEmbedded(r.body);
        if (!listings.length) errors.push(`Mobile(4): ${r.body.length}B`);
      } else { errors.push(`Mobile(4) HTTP ${r.status}`); }
    } catch (e) { errors.push(`Mobile(4): ${e.message}`); }
  }

  // ── Strategy 5: propSearch alt endpoint with Android UA ─────────────────
  if (listings.length === 0) {
    try {
      const altUrl =
        `https://www.magicbricks.com/propSearch.html` +
        `?cityName=${encodeURIComponent(city)}&proptype=${mbPropType}` +
        `&pgNo=1&resi_flag=1&newPropFlag=3&type=search`;
      const r = await fetchRaw(altUrl, ANDROID_HEADERS);
      if (r.status === 200) {
        const body = r.body.trim();
        if (body.startsWith('{') || body.startsWith('[')) {
          try { listings = parseMbJson(JSON.parse(body)); } catch (_) {}
        }
        if (!listings.length) listings = extractEmbedded(r.body);
        if (!listings.length) errors.push(`AltAndroid(5): ${body.length}B`);
      } else { errors.push(`AltAndroid(5) HTTP ${r.status}`); }
    } catch (e) { errors.push(`AltAndroid(5): ${e.message}`); }
  }

  // ── Strategy 6: Desktop listing page with session cookie ────────────────
  if (listings.length === 0) {
    try {
      let cookie = '';
      try {
        const home = await fetchRaw('https://www.magicbricks.com/', MINIMAL_HEADERS, 10000);
        const raw = home.headers['set-cookie'];
        if (raw) {
          cookie = (Array.isArray(raw) ? raw : [raw])
            .map(c => c.split(';')[0].trim()).filter(c => c.includes('=')).join('; ');
        }
      } catch (_) {}

      const pageUrl =
        `https://www.magicbricks.com/property-for-sale/residential-real-estate` +
        `?proptype=${mbPropType}&cityName=${encodeURIComponent(city)}`;
      const hdrs = { ...MINIMAL_HEADERS };
      if (cookie) hdrs['Cookie'] = cookie;
      const r = await fetchRaw(pageUrl, hdrs);
      if (r.status === 200) {
        listings = extractEmbedded(r.body);
        if (!listings.length) errors.push(`Desktop(6): ${r.body.length}B`);
      } else { errors.push(`Desktop(6) HTTP ${r.status}`); }
    } catch (e) { errors.push(`Desktop(6): ${e.message}`); }
  }

  // ── Fallback: TNRERA registered projects (government site, never IP-blocked) ──
  let source = 'MagicBricks';
  if (listings.length === 0) {
    try {
      const TNRERA_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
      const tnAll = [];
      const curYear = new Date().getFullYear();
      for (const yr of [curYear, curYear - 1]) {
        for (const type of ['Building', 'Normal_Layout']) {
          try {
            const url = `https://rera.tn.gov.in/cms/reg_projects_tamilnadu/${type}/${yr}.php`;
            const r = await fetchRaw(url, {
              'User-Agent': TNRERA_UA,
              'Accept':     'text/html,*/*',
              'Referer':    'https://rera.tn.gov.in/',
            }, 25000);
            if (r.status === 200) tnAll.push(...parseTnreraTable(r.body));
          } catch (_) {}
        }
      }
      const cityLower = city.toLowerCase();
      const filtered = tnAll.filter(p => {
        const d = (p.district || '').toLowerCase();
        return d.includes(cityLower) || cityLower.includes(d);
      });
      if (filtered.length > 0) {
        const seen2 = new Map();
        for (const p of filtered) {
          if (!seen2.has(p.reraNo)) seen2.set(p.reraNo, p);
        }
        listings = [...seen2.values()].map(p => ({
          id:           `tnrera_${p.reraNo.replace(/[^a-zA-Z0-9]/g,'_')}`,
          projectName:  p.projectName || p.reraNo,
          locality:     p.district || city,
          bhkType:      '',
          priceRupees:  0,
          pricePerSqft: 0,
          area:         0,
          status:       p.status || 'Registered',
          possession:   'N/A',
          completionYear: null,
          reraNo:       p.reraNo,
          developer:    p.developer || '',
          lat:          null,
          lng:          null,
        }));
        source = 'TNRERA';
      }
    } catch (e) { errors.push(`TNRERA: ${e.message}`); }
  }

  if (listings.length === 0) {
    return res.status(502).json({
      error:   `No listings found for "${city}". MagicBricks is blocking server IPs and TNRERA returned no results.`,
      details: errors.join(' | '),
    });
  }

  // ── Deduplicate ───────────────────────────────────────────────────────────
  const seen = new Map();
  for (const l of listings) {
    if (!seen.has(l.id)) seen.set(l.id, l);
    else if ((l.priceRupees || l.pricePerSqft) > (seen.get(l.id).priceRupees || 0))
      seen.set(l.id, l);
  }
  listings = [...seen.values()];

  // ── Geocode localities ────────────────────────────────────────────────────
  const localityList = [...new Set(listings.map(l => l.locality).filter(Boolean))];
  const geoCache     = await geocodeLocalities(localityList);
  listings = listings.map(l => {
    const g = geoCache[l.locality] || null;
    return { ...l, lat: g?.lat ?? null, lng: g?.lng ?? null };
  });

  // ── Radius filter ─────────────────────────────────────────────────────────
  if (hasRadius) {
    listings = listings.filter(l => {
      if (!l.lat) return true;
      const dLat = (l.lat - userLat) * Math.PI / 180;
      const dLon = (l.lng - userLng) * Math.PI / 180;
      const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(userLat * Math.PI / 180) * Math.cos(l.lat * Math.PI / 180) *
        Math.sin(dLon / 2) ** 2;
      return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) <= radius;
    });
  }

  res.json({ source, city, count: listings.length, listings });
});

module.exports = router;
