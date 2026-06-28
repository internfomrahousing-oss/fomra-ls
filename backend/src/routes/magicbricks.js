const express = require('express');
const https   = require('https');
const http    = require('http');
const { applyRadiusFilter } = require('../lib/listingRadius');
const router  = express.Router();

// ── City map ──────────────────────────────────────────────────────────────────

const CITY_MAP = {
  'chennai': 'Chennai', 'coimbatore': 'Coimbatore', 'madurai': 'Madurai',
  'tiruchirappalli': 'Tiruchirappalli', 'trichy': 'Tiruchirappalli',
  'salem': 'Salem', 'tirunelveli': 'Tirunelveli', 'vellore': 'Vellore',
  'erode': 'Erode', 'kancheepuram': 'Kancheepuram', 'kanchipuram': 'Kancheepuram',
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
    projectType:    'Building',
    registeredYear: null,
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

// ── LD+JSON ItemList + detail-page prices (works when API endpoints are blocked) ─

function extractLdJsonItems(html) {
  const blocks = html.match(/<script type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/gi) || [];
  const items = [];
  for (const block of blocks) {
    const m = block.match(/<script[^>]*>([\s\S]*?)<\/script>/i);
    if (!m) continue;
    try {
      const data = JSON.parse(m[1]);
      if (data['@type'] === 'ItemList' && Array.isArray(data.itemListElement)) {
        for (const el of data.itemListElement) {
          if (el.url && el.name) items.push({ url: el.url, name: el.name });
        }
      }
    } catch (_) {}
  }
  return items;
}

function parseFromMbDetailUrl(url, name) {
  const path = (url.split('?')[0] || '').split('/').pop() || '';
  const bhkM  = path.match(/(\d+)-BHK/i);
  const areaM = path.match(/(\d+)-Sq-ft/i);
  const locM  = path.match(/FOR-Sale-(.+?)-in-/i);
  const locality = locM ? locM[1].replace(/-/g, ' ').trim() : '';
  const cleanName = name
    .replace(/^\d+\s*BHK\s+Flat\s+for\s+Sale\s+in\s*/i, '')
    .replace(/,\s*Chennai.*$/i, '')
    .trim();
  return {
    bhkType:     bhkM ? `${bhkM[1]} BHK` : '',
    area:        areaM ? parseInt(areaM[1], 10) : 0,
    locality,
    projectName: cleanName || locality || name,
  };
}

async function fetchDetailPrice(url) {
  try {
    const r = await fetchRaw(url, MINIMAL_HEADERS, 15000);
    if (r.status !== 200) return 0;
    const m = r.body.match(/"price"\s*:\s*"?(\d+)"?/);
    return m ? parseInt(m[1], 10) : 0;
  } catch {
    return 0;
  }
}

async function fetchLdJsonListings(city, mbPropType) {
  const pageUrl =
    `https://www.magicbricks.com/property-for-sale/residential-real-estate` +
    `?proptype=${mbPropType}&cityName=${encodeURIComponent(city)}`;
  const r = await fetchRaw(pageUrl, MINIMAL_HEADERS, 25000);
  if (r.status !== 200) return [];

  const ldItems = extractLdJsonItems(r.body).slice(0, 12);
  if (!ldItems.length) return [];

  const results = [];
  const BATCH = 4;
  for (let i = 0; i < ldItems.length; i += BATCH) {
    const batch  = ldItems.slice(i, i + BATCH);
    const prices = await Promise.all(batch.map((item) => fetchDetailPrice(item.url)));
    batch.forEach((item, idx) => {
      const parsed = parseFromMbDetailUrl(item.url, item.name);
      const price  = prices[idx];
      const ppsf   = price > 0 && parsed.area > 0 ? Math.round(price / parsed.area) : 0;
      const nameKey = (parsed.projectName || parsed.locality || 'item')
        .replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30);
      results.push({
        id:             `mb_ld_${nameKey}_${i + idx}`,
        projectName:    parsed.projectName,
        locality:       parsed.locality,
        bhkType:        parsed.bhkType,
        priceRupees:    price,
        pricePerSqft:   ppsf,
        area:           parsed.area,
        status:         'Available',
        possession:     'N/A',
        completionYear: null,
        reraNo:         '',
        projectType:    'Building',
        registeredYear: null,
        lat:            null,
        lng:            null,
      });
    });
  }
  return results.filter((l) => l.priceRupees > 0);
}

// ── TNRERA HTML table parser (fallback source) ────────────────────────────────

// City aliases for TNRERA address text matching
const TNRERA_CITY_ALIASES = {
  "chennai":         ["chennai", "madras"],
  "kancheepuram":    ["kancheepuram", "kanchipuram"],
  "chengalpattu":    ["chengalpattu", "chengelpet"],
  "tiruchirappalli": ["tiruchirappalli", "trichy", "trichinopoly"],
  "thoothukudi":     ["thoothukudi", "tuticorin"],
  "tirunelveli":     ["tirunelveli", "tinnevelly"],
};

function parseTnreraTable(html) {
  const rows = [];
  function stripHtml(s) {
    return s.replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
  }
  // TNRERA tables have fixed columns (no reliable <th> district column):
  // 0: S.No.  1: Reg No.  2: Promoter+Address  3: Project Details+Name  4: Approval  5: Completion  6: Other  7: Status

  // Use greedy match to handle nested tables; fall back to full document if no <tbody>
  const tbodyM = html.match(/<tbody[^>]*>([\s\S]*)<\/tbody>/i);
  const searchContent = tbodyM ? tbodyM[1] : html;

  const rowPat = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowM;
  while ((rowM = rowPat.exec(searchContent)) !== null) {
    const cellPat = /<td[^>]*>([\s\S]*?)<\/td>/gi;
    const cells = [];
    let cellM;
    while ((cellM = cellPat.exec(rowM[1])) !== null) cells.push(stripHtml(cellM[1]));
    if (cells.length < 3) continue;
    // Skip header row (first cell is not a number)
    if (!/^\d+$/.test(cells[0])) continue;
    const reraNo = (cells[1] || "").replace(/\s+dated\s+.*/i, "").trim();
    const promoterAddr = cells[2] || "";
    const detailsCell  = cells[3] || "";
    const otherCell    = cells[6] || "";
    const status       = cells[7] || cells[5] || "Registered";
    // Extract project name from Project Name: "X" pattern (matches smart + straight quotes)
    const nameM = detailsCell.match(/Project\s+Name\s*:\s*["'‘’“”]([^"'‘’“”]+)["'‘’“”]/i);
    const projectName = nameM ? nameM[1].trim() : (detailsCell.split("-")[0].trim().slice(0, 60) || reraNo);
    // Combine searchable address text for city matching (no dedicated district column)
    const addressText = promoterAddr + " " + detailsCell + " " + otherCell;
    if (!projectName && !reraNo) continue;
    rows.push({ reraNo, projectName: projectName || reraNo, address: addressText, status });
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
  // MagicBricks blocks all serverless IPs — skip on Netlify and Vercel
  const onNetlify = !!process.env.NETLIFY;
  const onVercel  = !!process.env.VERCEL;
  const skipMb    = onNetlify || onVercel;

  const searchApiBase =
    `https://www.magicbricks.com/mbsrp/propertySearch.html` +
    `?multiLang=en&cityName=${encodeURIComponent(city)}` +
    `&proptype=${mbPropType}&pgNo=1&resi_flag=1&newPropFlag=3&type=search`;

  // ── Strategy 1: Android Dalvik UA (mimics mobile app) ──────────────────
  if (!skipMb && listings.length === 0) {
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
  if (!skipMb && listings.length === 0) {
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
  if (!skipMb && listings.length === 0) {
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
  if (!skipMb && listings.length === 0) {
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
  if (!skipMb && listings.length === 0) {
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
  if (!skipMb && listings.length === 0) {
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

  // ── Strategy 7: LD+JSON listing page + detail-page prices ───────────────
  if (!skipMb && listings.length === 0) {
    try {
      const ldListings = await fetchLdJsonListings(city, mbPropType);
      if (ldListings.length > 0) {
        listings = ldListings;
      } else {
        errors.push('LdJson(7): no priced listings');
      }
    } catch (e) { errors.push(`LdJson(7): ${e.message}`); }
  }

  // ── Fallback: TNRERA (all years in parallel — safe within Netlify 10s) ──
  let source = 'MagicBricks';
  if (listings.length === 0) {
    try {
      const TNRERA_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36';
      const TNRERA_HDR = { 'User-Agent': TNRERA_UA, 'Accept': 'text/html,*/*', 'Referer': 'https://rera.tn.gov.in/' };
      const curYear = new Date().getFullYear();
      // Start from curYear-1 — current year file often 404s until TNRERA publishes it
      const years = [curYear - 1, curYear - 2, curYear - 3, curYear - 4];
      const types = ['Building', 'Normal_Layout'];

      // Fetch all 6 combinations in parallel with 8s timeout each
      const tnResults = await Promise.allSettled(
        years.flatMap(yr => types.map(async (type) => {
          const url = `https://rera.tn.gov.in/cms/reg_projects_tamilnadu/${type}/${yr}.php`;
          const r = await fetchRaw(url, TNRERA_HDR, 8000);
          return r.status === 200 ? { rows: parseTnreraTable(r.body), type, yr } : null;
        }))
      );

      const tnAll = [];
      for (const result of tnResults) {
        if (result.status === 'fulfilled' && result.value) {
          const { rows, type, yr } = result.value;
          console.log(`[TNRERA] ${type}/${yr}: ${rows.length} rows`);
          rows.forEach(p => tnAll.push({ ...p, _type: type, _yr: yr }));
        } else if (result.status === 'rejected') {
          console.log(`[TNRERA] fetch failed: ${result.reason}`);
        }
      }
      console.log(`[TNRERA] total rows across all files: ${tnAll.length}`);

      const cityLower = city.toLowerCase();
      const cityAliases = TNRERA_CITY_ALIASES[cityLower] || [cityLower];

      // Search city name (+ aliases) in combined address text
      let filtered = tnAll.filter(p =>
        cityAliases.some(alias => (p.address || '').toLowerCase().includes(alias))
      );
      console.log(`[TNRERA] city="${city}" aliases=${JSON.stringify(cityAliases)} filtered=${filtered.length}`);

      // If city filter yields nothing but we have TN-wide data, show all (better than an error)
      if (filtered.length === 0 && tnAll.length > 0) {
        console.log('[TNRERA] city filter empty — returning all TN projects');
        filtered = tnAll;
      }

      if (filtered.length > 0) {
        const seen2 = new Map();
        for (const p of filtered) {
          if (!seen2.has(p.reraNo)) seen2.set(p.reraNo, p);
        }
        listings = [...seen2.values()].map(p => ({
          id:             `tnrera_${p.reraNo.replace(/[^a-zA-Z0-9]/g,'_')}`,
          projectName:    p.projectName || p.reraNo,
          locality:       (p.address || '').slice(0, 120) || city,
          bhkType:        '',
          priceRupees:    0,
          pricePerSqft:   0,
          area:           0,
          status:         p.status || 'Registered',
          possession:     'N/A',
          completionYear: null,
          reraNo:         p.reraNo,
          developer:      '',
          projectType:    p._type === 'Normal_Layout' ? 'Layout' : 'Building',
          registeredYear: p._yr || null,
          lat:            null,
          lng:            null,
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

  // ── Geocode localities (limited on serverless to stay within timeout) ──────
  const localityList = [...new Set(listings.map(l => l.locality).filter(Boolean))]
    .slice(0, skipMb ? 20 : 200);
  if (localityList.length > 0) {
    const geoCache = await geocodeLocalities(localityList);
    listings = listings.map(l => {
      const g = geoCache[l.locality] || null;
      return { ...l, lat: g?.lat ?? l.lat ?? null, lng: g?.lng ?? l.lng ?? null };
    });
  }

  let radiusNote;
  if (hasRadius) {
    const filtered = applyRadiusFilter(listings, userLat, userLng, radius);
    listings = filtered.listings;
    radiusNote = filtered.radiusNote;
  }

  res.json({ source, city, count: listings.length, listings, radiusNote });
});

module.exports = router;
