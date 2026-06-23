/**
 * TN Land Records Scraper
 *
 * Routes:
 *   GET /api/tnlands/districts           — list of TN districts (static fallback)
 *   GET /api/tnlands/taluks?dc=          — taluks for a district code
 *   GET /api/tnlands/villages?dc=&tc=    — villages for a taluk code
 *   GET /api/tnlands/patta               — Patta/Chitta from eservices.tn.gov.in
 *   GET /api/tnlands/ec/zones            — EC zones (static)
 *   GET /api/tnlands/ec/districts?zone=  — EC districts for a zone
 *   GET /api/tnlands/ec/sros?zone=&dc=   — SROs for a district
 *   GET /api/tnlands/ec/search           — EC search results
 */

const express = require('express');
const https   = require('https');
const http    = require('http');
const router  = express.Router();

// ── Cookie helpers ─────────────────────────────────────────────────────────────

function parseCookies(setCookieArr) {
  if (!Array.isArray(setCookieArr) || setCookieArr.length === 0) return '';
  return setCookieArr
    .map(c => c.split(';')[0].trim())
    .filter(Boolean)
    .join('; ');
}

function mergeCookies(existing, newCookies) {
  if (!existing && !newCookies) return '';
  if (!existing) return newCookies || '';
  if (!newCookies) return existing;
  const map = {};
  for (const part of [...existing.split('; '), ...newCookies.split('; ')]) {
    const eq = part.indexOf('=');
    if (eq > 0) map[part.slice(0, eq)] = part.slice(eq + 1);
  }
  return Object.entries(map).map(([k, v]) => `${k}=${v}`).join('; ');
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

function fetchRaw(urlStr, opts = {}, _depth = 0) {
  return new Promise((resolve, reject) => {
    if (_depth > 5) return reject(new Error('Too many redirects'));

    let parsed;
    try { parsed = new URL(urlStr); } catch (e) { return reject(e); }

    const lib = parsed.protocol === 'https:' ? https : http;

    const headers = {
      'User-Agent':      BROWSER_UA,
      'Accept':          'text/html,application/xhtml+xml,*/*;q=0.9',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'identity',
      'Connection':      'keep-alive',
      ...opts.headers,
    };
    if (opts.cookies) headers['Cookie'] = opts.cookies;

    const method = opts.method === 'POST' ? 'POST' : 'GET';

    if (method === 'POST') {
      headers['Content-Type']   = opts.contentType || 'application/x-www-form-urlencoded';
      headers['Content-Length'] = Buffer.byteLength(opts.body || '');
    }

    const reqOpts = {
      hostname: parsed.hostname,
      port:     parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path:     (parsed.pathname + parsed.search) || '/',
      method,
      headers,
    };

    const req = lib.request(reqOpts, (res) => {
      const newCookies    = parseCookies(res.headers['set-cookie']);
      const mergedCookies = mergeCookies(opts.cookies, newCookies);

      // Follow 3xx redirects (GET only after the redirect)
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        const loc  = res.headers.location;
        const dest = loc.startsWith('http') ? loc : `${parsed.protocol}//${parsed.hostname}${loc}`;
        res.resume();
        return fetchRaw(
          dest,
          { ...opts, method: 'GET', body: undefined, cookies: mergedCookies },
          _depth + 1
        )
          .then(r => resolve({ ...r, cookies: mergeCookies(mergedCookies, r.cookies) }))
          .catch(reject);
      }

      const chunks = [];
      res.on('data',  c => chunks.push(c));
      res.on('end',   () => resolve({
        status:  res.statusCode,
        headers: res.headers,
        body:    Buffer.concat(chunks).toString('utf8'),
        cookies: mergedCookies,
      }));
      res.on('error', reject);
    });

    req.setTimeout(25000, () => { req.destroy(); reject(new Error('Request timed out')); });
    req.on('error', reject);
    if (method === 'POST' && opts.body) req.write(opts.body);
    req.end();
  });
}

// ── ASP.NET helpers ───────────────────────────────────────────────────────────

function extractAspNetTokens(html) {
  const get = (name) => {
    const m = html.match(new RegExp(`id="${name}"[^>]*value="([^"]*)"`, 'i')) ||
              html.match(new RegExp(`name="${name}"[^>]*value="([^"]*)"`, 'i'));
    return m ? m[1] : '';
  };
  return {
    __VIEWSTATE:          get('__VIEWSTATE'),
    __VIEWSTATEGENERATOR: get('__VIEWSTATEGENERATOR'),
    __EVENTVALIDATION:    get('__EVENTVALIDATION'),
  };
}

function encodeForm(obj) {
  return Object.entries(obj)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v ?? '')}`)
    .join('&');
}

// Parse <select id="X"> options → [{code, name}]
// Tries the bare name plus the two common ASP.NET ContentPlaceHolder prefixes.
function parseSelectOptions(html, baseName) {
  const candidates = [
    baseName,
    `ContentPlaceHolder1_${baseName}`,
    `ctl00_ContentPlaceHolder1_${baseName}`,
    // name attribute uses $ instead of _
    `ContentPlaceHolder1$${baseName}`,
    `ctl00$ContentPlaceHolder1$${baseName}`,
  ];

  for (const id of candidates) {
    const escaped = id.replace(/\$/g, '\\$');
    const selPat  = new RegExp(
      `<select[^>]+(?:id|name)="${escaped}"[^>]*>([\\s\\S]*?)<\\/select>`, 'i'
    );
    const selMatch = html.match(selPat);
    if (!selMatch) continue;

    const optPat = /<option[^>]+value="([^"]*)"[^>]*>([^<]*)<\/option>/gi;
    const opts   = [];
    let m;
    while ((m = optPat.exec(selMatch[1])) !== null) {
      const code = m[1].trim();
      const name = m[2].trim().replace(/^[-\s]*select[-\s]*/i, '').trim();
      if (code && name && !name.toLowerCase().includes('select')) opts.push({ code, name });
    }
    if (opts.length > 0) return opts;
  }
  return [];
}

// Extract the HTML payload from an ASP.NET ScriptManager UpdatePanel delta response.
// The format is length-delimited: "len|type|id|content|" where len = byte-length of content.
// We CANNOT naively split on '|' because content may contain '|'.
function extractUpdatePanelHtml(body) {
  if (!body.includes('|updatePanel|') && !body.includes('|pageContent|')) return body;

  let pos = 0;
  const htmlParts = [];

  while (pos < body.length) {
    // Read the length field
    const pipe1 = body.indexOf('|', pos);
    if (pipe1 === -1) break;
    const len = parseInt(body.substring(pos, pipe1), 10);
    if (isNaN(len)) { pos = pipe1 + 1; continue; }

    // Read the type field
    const pipe2 = body.indexOf('|', pipe1 + 1);
    if (pipe2 === -1) break;
    const type = body.substring(pipe1 + 1, pipe2);

    // Read the id field
    const pipe3 = body.indexOf('|', pipe2 + 1);
    if (pipe3 === -1) break;

    // Content starts right after pipe3 and is exactly `len` chars long
    const contentStart = pipe3 + 1;
    if (contentStart + len > body.length) break;
    const content = body.substring(contentStart, contentStart + len);

    if (type === 'updatePanel' && content.length > 0) {
      htmlParts.push(content);
    }

    // Advance past content + trailing '|'
    pos = contentStart + len + 1;
  }

  // Return all updatePanel fragments concatenated; fall back to naive approach if nothing found
  if (htmlParts.length > 0) return htmlParts.join('');

  // Naive fallback (works when content has no '|')
  const parts  = body.split('|');
  const htmlIdx = parts.findIndex(p => p.startsWith('<'));
  return htmlIdx >= 0 ? parts.slice(htmlIdx).join('|') : body;
}

// ── Patta (eservices.tn.gov.in) ───────────────────────────────────────────────

const PATTA_BASE = 'https://eservices.tn.gov.in';
const PATTA_PATH = '/eservicesnew/land/patta_chitta_view.html';
const PATTA_URL  = PATTA_BASE + PATTA_PATH + '?lang=en';

const PATTA_CTRL = {
  district: 'ctl00$ContentPlaceHolder1$ddlDistrict',
  taluk:    'ctl00$ContentPlaceHolder1$ddlTaluk',
  village:  'ctl00$ContentPlaceHolder1$ddlVillage',
  surveyNo: 'ctl00$ContentPlaceHolder1$txtSurveyNo',
  subDiv:   'ctl00$ContentPlaceHolder1$txtSubDivisionNo',
  button:   'ctl00$ContentPlaceHolder1$btnGetPCDetails',
};

const STATIC_TN_DISTRICTS = [
  { code: '001', name: 'Ariyalur' },       { code: '002', name: 'Chengalpattu' },
  { code: '003', name: 'Chennai' },        { code: '004', name: 'Coimbatore' },
  { code: '005', name: 'Cuddalore' },      { code: '006', name: 'Dharmapuri' },
  { code: '007', name: 'Dindigul' },       { code: '008', name: 'Erode' },
  { code: '009', name: 'Kallakurichi' },   { code: '010', name: 'Kancheepuram' },
  { code: '011', name: 'Kanniyakumari' },  { code: '012', name: 'Karur' },
  { code: '013', name: 'Krishnagiri' },    { code: '014', name: 'Madurai' },
  { code: '015', name: 'Mayiladuthurai' }, { code: '016', name: 'Nagapattinam' },
  { code: '017', name: 'Namakkal' },       { code: '018', name: 'Nilgiris' },
  { code: '019', name: 'Perambalur' },     { code: '020', name: 'Pudukkottai' },
  { code: '021', name: 'Ramanathapuram' }, { code: '022', name: 'Ranipet' },
  { code: '023', name: 'Salem' },          { code: '024', name: 'Sivagangai' },
  { code: '025', name: 'Tenkasi' },        { code: '026', name: 'Thanjavur' },
  { code: '027', name: 'Theni' },          { code: '028', name: 'Thoothukudi' },
  { code: '029', name: 'Tiruchirappalli' },{ code: '030', name: 'Tirunelveli' },
  { code: '031', name: 'Tirupathur' },     { code: '032', name: 'Tiruppur' },
  { code: '033', name: 'Tiruvallur' },     { code: '034', name: 'Tiruvannamalai' },
  { code: '035', name: 'Tiruvarur' },      { code: '036', name: 'Vellore' },
  { code: '037', name: 'Viluppuram' },     { code: '038', name: 'Virudhunagar' },
];

const PATTA_CACHE_TTL = 10 * 60 * 1000; // 10 min
// Cache stores { html, cookies, time } so session stays valid across requests
let _pattaPageCache = null;

async function getPattaPage() {
  const now = Date.now();
  if (_pattaPageCache && (now - _pattaPageCache.time) < PATTA_CACHE_TTL) {
    return _pattaPageCache;
  }
  const res = await fetchRaw(PATTA_URL, { headers: { Referer: PATTA_BASE } });
  if (res.status !== 200) throw new Error(`Patta page returned HTTP ${res.status}`);
  const ctx = { html: res.body, cookies: res.cookies, time: now };
  _pattaPageCache = ctx;
  return ctx;
}

async function pattaPostback(pageCtx, eventTarget, fieldValues) {
  const tokens = extractAspNetTokens(pageCtx.html);
  const body   = encodeForm({
    __EVENTTARGET:          eventTarget,
    __EVENTARGUMENT:        '',
    __ASYNCPOST:            'true',
    __VIEWSTATE:            tokens.__VIEWSTATE,
    __VIEWSTATEGENERATOR:   tokens.__VIEWSTATEGENERATOR,
    __EVENTVALIDATION:      tokens.__EVENTVALIDATION,
    ...fieldValues,
  });

  const res = await fetchRaw(PATTA_BASE + PATTA_PATH, {
    method:  'POST',
    body,
    cookies: pageCtx.cookies,
    headers: {
      Referer:             PATTA_URL,
      Origin:              PATTA_BASE,
      'X-MicrosoftAjax':  'Delta=true',
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  const html = extractUpdatePanelHtml(res.body);
  return { html, cookies: mergeCookies(pageCtx.cookies, res.cookies) };
}

function parsePattaResult(html) {
  const fields = {};
  const owners = [];

  const tablePat = /<table[^>]*>([\s\S]*?)<\/table>/gi;
  let tMatch;

  while ((tMatch = tablePat.exec(html)) !== null) {
    const inner = tMatch[1];
    const rowPat = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    const tableRows = [];
    let rowMatch;

    while ((rowMatch = rowPat.exec(inner)) !== null) {
      const cells = [];
      const cp = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
      let cm;
      while ((cm = cp.exec(rowMatch[1])) !== null) {
        const txt = cm[1]
          .replace(/<[^>]+>/g, ' ')
          .replace(/&nbsp;/g, ' ')
          .replace(/&#\d+;/g, ' ')
          .replace(/&amp;/g, '&')
          .replace(/\s+/g, ' ')
          .trim();
        if (txt) cells.push(txt);
      }
      if (cells.length > 0) tableRows.push(cells);
    }

    if (tableRows.length === 0) continue;

    // 2-column label-value table → patta fields
    if (tableRows.length >= 2 && tableRows.every(r => r.length === 2)) {
      tableRows.forEach(([k, v]) => { if (k && v) fields[k] = v; });
    }
    // Multi-column header table → owner/survey rows
    else if (tableRows.length >= 2 && tableRows[0].length >= 2) {
      const hdrs = tableRows[0];
      for (let i = 1; i < tableRows.length; i++) {
        if (tableRows[i].some(c => c.length > 0)) {
          const owner = {};
          hdrs.forEach((h, idx) => { if (tableRows[i][idx]) owner[h] = tableRows[i][idx]; });
          if (Object.keys(owner).length > 0) owners.push(owner);
        }
      }
    }
  }

  if (Object.keys(fields).length === 0 && owners.length === 0) return null;
  return { fields, owners };
}

// ── Patta Routes ──────────────────────────────────────────────────────────────

router.get('/districts', async (req, res) => {
  try {
    const { html } = await getPattaPage();
    const districts = parseSelectOptions(html, 'ddlDistrict')
      .filter(d => !d.name.toLowerCase().includes('select'));
    res.json(districts.length > 0 ? districts : STATIC_TN_DISTRICTS);
  } catch (_) {
    res.json(STATIC_TN_DISTRICTS);
  }
});

router.get('/taluks', async (req, res) => {
  const { dc } = req.query;
  if (!dc) return res.status(400).json({ error: 'dc (districtCode) required' });

  try {
    const pageCtx = await getPattaPage();
    const ctx     = await pattaPostback(pageCtx, PATTA_CTRL.district, {
      [PATTA_CTRL.district]: dc,
    });
    const taluks = parseSelectOptions(ctx.html, 'ddlTaluk');
    if (taluks.length === 0) return res.status(502).json({ error: 'Could not fetch taluks — check district code.' });
    res.json(taluks);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/villages', async (req, res) => {
  const { dc, tc } = req.query;
  if (!dc || !tc) return res.status(400).json({ error: 'dc and tc required' });

  try {
    const pageCtx  = await getPattaPage();
    const afterDist = await pattaPostback(pageCtx, PATTA_CTRL.district, {
      [PATTA_CTRL.district]: dc,
    });
    const afterTaluk = await pattaPostback(afterDist, PATTA_CTRL.taluk, {
      [PATTA_CTRL.district]: dc,
      [PATTA_CTRL.taluk]:    tc,
    });
    const villages = parseSelectOptions(afterTaluk.html, 'ddlVillage');
    if (villages.length === 0) return res.status(502).json({ error: 'Could not fetch villages — check taluk code.' });
    res.json(villages);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/patta', async (req, res) => {
  const { dc, tc, vc, surveyNo, subDiv } = req.query;
  if (!dc || !tc || !vc || !surveyNo) {
    return res.status(400).json({ error: 'dc, tc, vc, surveyNo required' });
  }

  try {
    const pageCtx = await getPattaPage();
    const tokens  = extractAspNetTokens(pageCtx.html);

    const body = encodeForm({
      __EVENTTARGET:          '',
      __EVENTARGUMENT:        '',
      __VIEWSTATE:            tokens.__VIEWSTATE,
      __VIEWSTATEGENERATOR:   tokens.__VIEWSTATEGENERATOR,
      __EVENTVALIDATION:      tokens.__EVENTVALIDATION,
      [PATTA_CTRL.district]:  dc,
      [PATTA_CTRL.taluk]:     tc,
      [PATTA_CTRL.village]:   vc,
      [PATTA_CTRL.surveyNo]:  surveyNo,
      [PATTA_CTRL.subDiv]:    subDiv || '',
      [PATTA_CTRL.button]:    'View Patta & FMB',
    });

    const result = await fetchRaw(PATTA_BASE + PATTA_PATH, {
      method:  'POST',
      body,
      cookies: pageCtx.cookies,
      headers: { Referer: PATTA_URL, Origin: PATTA_BASE },
    });

    if (result.status !== 200) {
      return res.status(502).json({ error: `Portal returned HTTP ${result.status}` });
    }

    const parsed = parsePattaResult(result.body);
    if (!parsed) {
      return res.status(422).json({
        error: 'No patta data found. Verify district/taluk/village codes and survey number.',
        hint:  'Use the exact survey number as shown in your land document.',
      });
    }

    res.json({ source: 'eservices.tn.gov.in', ...parsed });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

// ── EC (tnreginet.gov.in) ─────────────────────────────────────────────────────

const EC_BASE = 'https://tnreginet.gov.in';
const EC_PATH = '/portal/webHP.aspx';
const EC_URL  = `${EC_BASE}${EC_PATH}?appname=EC`;

const EC_CTRL = {
  zone:     'ctl00$ContentPlaceHolder1$ddlZone',
  district: 'ctl00$ContentPlaceHolder1$ddlDistrict',
  sro:      'ctl00$ContentPlaceHolder1$ddlSRO',
  village:  'ctl00$ContentPlaceHolder1$txtVillageName',
  surveyNo: 'ctl00$ContentPlaceHolder1$txtSurveyNo',
  subDiv:   'ctl00$ContentPlaceHolder1$txtSubdivisionNo',
  fromDate: 'ctl00$ContentPlaceHolder1$txtFromDate',
  toDate:   'ctl00$ContentPlaceHolder1$txtToDate',
  search:   'ctl00$ContentPlaceHolder1$btnSearch',
};

const EC_ZONES = [
  { code: '1', name: 'North' },
  { code: '2', name: 'South' },
  { code: '3', name: 'Central' },
];

let _ecPageCache = null; // { html, cookies, time }

async function getEcPage() {
  const now = Date.now();
  if (_ecPageCache && (now - _ecPageCache.time) < PATTA_CACHE_TTL) return _ecPageCache;
  const res = await fetchRaw(EC_URL, { headers: { Referer: EC_BASE } });
  if (res.status !== 200) throw new Error(`EC page returned HTTP ${res.status}`);
  const ctx = { html: res.body, cookies: res.cookies, time: now };
  _ecPageCache = ctx;
  return ctx;
}

async function ecPostback(pageCtx, eventTarget, fieldValues) {
  const tokens = extractAspNetTokens(pageCtx.html);
  const body   = encodeForm({
    __EVENTTARGET:          eventTarget,
    __EVENTARGUMENT:        '',
    __ASYNCPOST:            'true',
    __VIEWSTATE:            tokens.__VIEWSTATE,
    __VIEWSTATEGENERATOR:   tokens.__VIEWSTATEGENERATOR,
    __EVENTVALIDATION:      tokens.__EVENTVALIDATION,
    ...fieldValues,
  });

  const res = await fetchRaw(EC_BASE + EC_PATH + '?appname=EC', {
    method:  'POST',
    body,
    cookies: pageCtx.cookies,
    headers: {
      Referer:             EC_URL,
      Origin:              EC_BASE,
      'X-MicrosoftAjax':  'Delta=true',
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  const html = extractUpdatePanelHtml(res.body);
  return { html, cookies: mergeCookies(pageCtx.cookies, res.cookies) };
}

function parseEcResults(html) {
  const results  = [];
  const tablePat = /<table[^>]*>([\s\S]*?)<\/table>/gi;
  let tMatch;

  while ((tMatch = tablePat.exec(html)) !== null) {
    const inner  = tMatch[1];
    const rowPat = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    const rows   = [];
    let rowMatch;

    while ((rowMatch = rowPat.exec(inner)) !== null) {
      const cells = [];
      const cp = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
      let cm;
      while ((cm = cp.exec(rowMatch[1])) !== null) {
        const txt = cm[1]
          .replace(/<[^>]+>/g, '')
          .replace(/&nbsp;/g, ' ')
          .replace(/&amp;/g, '&')
          .replace(/\s+/g, ' ')
          .trim();
        cells.push(txt);
      }
      if (cells.length > 0) rows.push(cells);
    }

    if (rows.length < 2 || rows[0].length < 2) continue;
    // Skip navigation or menu tables
    if (rows[0].some(h => /home|logout|profile|menu/i.test(h))) continue;

    const headers = rows[0];
    for (let i = 1; i < rows.length; i++) {
      if (rows[i].some(c => c.length > 0)) {
        const record = {};
        headers.forEach((h, idx) => { record[h || `col${idx}`] = rows[i][idx] || ''; });
        results.push(record);
      }
    }
  }

  return results;
}

// ── EC Routes ─────────────────────────────────────────────────────────────────

router.get('/ec/zones', (req, res) => res.json(EC_ZONES));

router.get('/ec/districts', async (req, res) => {
  const { zone } = req.query;
  if (!zone) return res.status(400).json({ error: 'zone required' });

  try {
    const pageCtx   = await getEcPage();
    const ctx       = await ecPostback(pageCtx, EC_CTRL.zone, { [EC_CTRL.zone]: zone });
    const districts = parseSelectOptions(ctx.html, 'ddlDistrict');
    if (districts.length === 0) return res.status(502).json({ error: 'Could not fetch EC districts.' });
    res.json(districts);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/ec/sros', async (req, res) => {
  const { zone, dc } = req.query;
  if (!zone || !dc) return res.status(400).json({ error: 'zone and dc required' });

  try {
    const pageCtx   = await getEcPage();
    const afterZone = await ecPostback(pageCtx, EC_CTRL.zone, { [EC_CTRL.zone]: zone });
    const afterDist = await ecPostback(afterZone, EC_CTRL.district, {
      [EC_CTRL.zone]:     zone,
      [EC_CTRL.district]: dc,
    });
    const sros = parseSelectOptions(afterDist.html, 'ddlSRO');
    if (sros.length === 0) return res.status(502).json({ error: 'Could not fetch SROs.' });
    res.json(sros);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/ec/search', async (req, res) => {
  const { zone, dc, sro, surveyNo, subDiv, fromDate, toDate } = req.query;
  if (!zone || !dc || !sro || !surveyNo || !fromDate || !toDate) {
    return res.status(400).json({
      error: 'zone, dc, sro, surveyNo, fromDate, toDate required (dates: DD/MM/YYYY)',
    });
  }

  try {
    const pageCtx = await getEcPage();
    const tokens  = extractAspNetTokens(pageCtx.html);

    const body = encodeForm({
      __EVENTTARGET:          '',
      __EVENTARGUMENT:        '',
      __VIEWSTATE:            tokens.__VIEWSTATE,
      __VIEWSTATEGENERATOR:   tokens.__VIEWSTATEGENERATOR,
      __EVENTVALIDATION:      tokens.__EVENTVALIDATION,
      [EC_CTRL.zone]:         zone,
      [EC_CTRL.district]:     dc,
      [EC_CTRL.sro]:          sro,
      [EC_CTRL.village]:      req.query.village || '',
      [EC_CTRL.surveyNo]:     surveyNo,
      [EC_CTRL.subDiv]:       subDiv || '',
      [EC_CTRL.fromDate]:     fromDate,
      [EC_CTRL.toDate]:       toDate,
      [EC_CTRL.search]:       'Search',
    });

    const result = await fetchRaw(EC_BASE + EC_PATH + '?appname=EC', {
      method:  'POST',
      body,
      cookies: pageCtx.cookies,
      headers: { Referer: EC_URL, Origin: EC_BASE },
    });

    if (result.status !== 200) {
      return res.status(502).json({ error: `EC portal returned HTTP ${result.status}` });
    }

    const records = parseEcResults(result.body);
    if (records.length === 0) {
      return res.status(404).json({
        error: 'No EC records found for the given parameters.',
        hint:  'Try a wider date range or verify the survey number and SRO.',
      });
    }

    res.json({ source: 'tnreginet.gov.in', count: records.length, records });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

module.exports = router;
