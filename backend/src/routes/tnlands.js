/**
 * TN Land Records Scraper
 *
 * Patta (eservices.tn.gov.in) — uses direct AJAX endpoint (ajax.html) for dropdowns,
 * then POST to chittaExtract_ta.html for the actual patta lookup.
 *
 * EC (tnreginet.gov.in) — uses the JSP portal REST-style combo loaders (POST with CSRF)
 * for dropdowns, then POST to webHP for the EC search.
 *
 * Routes:
 *   GET /api/tnlands/districts             — TN districts (live from Patta page, static fallback)
 *   GET /api/tnlands/taluks?dc=            — taluks for a district code
 *   GET /api/tnlands/villages?dc=&tc=      — villages for a taluk code
 *   GET /api/tnlands/patta                 — Patta/Chitta extract
 *   GET /api/tnlands/ec/zones              — EC zones (static)
 *   GET /api/tnlands/ec/districts?zone=    — EC districts for a zone
 *   GET /api/tnlands/ec/sros?zone=&dc=     — SROs for a district
 *   GET /api/tnlands/ec/search             — EC encumbrance search results
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
// Handles both double-quoted and single-quoted HTML/XML attributes.
function parseSelectOptions(html, baseName) {
  const candidates = [
    baseName,
    `ContentPlaceHolder1_${baseName}`,
    `ctl00_ContentPlaceHolder1_${baseName}`,
    `ContentPlaceHolder1$${baseName}`,
    `ctl00$ContentPlaceHolder1$${baseName}`,
  ];

  for (const id of candidates) {
    const escaped = id.replace(/\$/g, '\\$');
    const selPat  = new RegExp(
      `<select[^>]+(?:id|name)=["']${escaped}["'][^>]*>([\\s\\S]*?)<\\/select>`, 'i'
    );
    const selMatch = html.match(selPat);
    if (!selMatch) continue;

    const optPat = /<option[^>]+value=["']([^"']*)["'][^>]*>([^<]*)<\/option>/gi;
    const opts   = [];
    let m;
    while ((m = optPat.exec(selMatch[1])) !== null) {
      const code = m[1].trim();
      const name = m[2].trim().replace(/^[-\s]*select[-\s]*/i, '').trim();
      if (code && code !== '-1' && name && !name.toLowerCase().includes('select')) opts.push({ code, name });
    }
    if (opts.length > 0) return opts;
  }
  return [];
}

// Parse AJAX responses that may be JSON arrays or HTML <select> fragments.
// JSON shape tried: [{code, name}] or [{<key with "code">, <key with "name/desc/label">}]
function parseJsonOrSelectOptions(body, baseName) {
  const trimmed = body.trim();
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    try {
      const data = JSON.parse(trimmed);
      const arr  = Array.isArray(data) ? data : (data.data || data.result || data.list || []);
      if (arr.length > 0) {
        const item    = arr[0];
        const keys    = Object.keys(item);
        const codeKey = keys.find(k => /code/i.test(k));
        const nameKey = keys.find(k => /name|desc|label|text/i.test(k));
        if (codeKey && nameKey) {
          return arr
            .map(d => ({ code: String(d[codeKey]).trim(), name: String(d[nameKey]).trim() }))
            .filter(d => d.code && d.name && !d.name.toLowerCase().includes('select'));
        }
      }
    } catch (_) {}
  }
  return parseSelectOptions(body, baseName);
}

// ── Patta (eservices.tn.gov.in) ───────────────────────────────────────────────

const PATTA_BASE = 'https://eservices.tn.gov.in';
const PATTA_HOME_URL = `${PATTA_BASE}/eservicesnew/home.html`;
const PATTA_PATH = '/eservicesnew/land/chittaExtract_ta.html';
const PATTA_FORM_PATH = '/eservicesnew/land/chittaNewRuralTamil.html';
const PATTA_AJAX_PATH = '/eservicesnew/land/ajax.html';
const PATTA_URL  = PATTA_BASE + PATTA_PATH + '?lan=ta';

const PATTA_CTRL = {
  district: 'districtCode',
  taluk:    'talukCode',
  village:  'villageCode',
  viewOpt:  'viewOpt',
  landtype: 'landtype',
  pattaNo:  'pattaNo',
  owner:    'searchPattaName',
  surveyNo: 'surveyNo',
  subDiv:   'subdivNo',
  mobile:   'mobileno',
  otp:      'otpno',
  task:     'task',
  searchpattano: 'searchpattano',
  chkrno:   'chkrno',
  ajaxRno:  'ajax_rno',
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

// Static TN taluk dataset — codes follow eservices.tn.gov.in 3-digit zero-padded convention.
// ajax.html is blocked for server-side requests; this static data is the fallback.
const STATIC_TN_TALUKS = {
  '001': [{ code:'001',name:'Ariyalur' },{ code:'002',name:'Jayankondam' },{ code:'003',name:'Sendurai' },{ code:'004',name:'T. Palur' }],
  '002': [{ code:'001',name:'Chengalpattu' },{ code:'002',name:'Cheyyur' },{ code:'003',name:'Madurantakam' },{ code:'004',name:'St. Thomas Mount' },{ code:'005',name:'Tambaram' },{ code:'006',name:'Thiruporur' },{ code:'007',name:'Uthiramerur' },{ code:'008',name:'Vandalur' }],
  '003': [{ code:'001',name:'Ambattur' },{ code:'002',name:'Chennai South' },{ code:'003',name:'Egmore-Nungambakkam' },{ code:'004',name:'Mambalam-Guindy' },{ code:'005',name:'Perambur-Purasawalkam' },{ code:'006',name:'Sholinganallur' },{ code:'007',name:'Tiruvottiyur' }],
  '004': [{ code:'001',name:'Annur' },{ code:'002',name:'Coimbatore North' },{ code:'003',name:'Coimbatore South' },{ code:'004',name:'Kinathukadavu' },{ code:'005',name:'Mettupalayam' },{ code:'006',name:'Palladam' },{ code:'007',name:'Pollachi' },{ code:'008',name:'Sulur' }],
  '005': [{ code:'001',name:'Chidambaram' },{ code:'002',name:'Cuddalore' },{ code:'003',name:'Kattumannarkoil' },{ code:'004',name:'Kurinjipadi' },{ code:'005',name:'Panruti' },{ code:'006',name:'Vriddhachalam' }],
  '006': [{ code:'001',name:'Dharmapuri' },{ code:'002',name:'Harur' },{ code:'003',name:'Karimangalam' },{ code:'004',name:'Nallampalli' },{ code:'005',name:'Palacode' },{ code:'006',name:'Pennagaram' }],
  '007': [{ code:'001',name:'Attur' },{ code:'002',name:'Dindigul' },{ code:'003',name:'Natham' },{ code:'004',name:'Nilakottai' },{ code:'005',name:'Oddanchatram' },{ code:'006',name:'Palani' },{ code:'007',name:'Reddiyarchatram' },{ code:'008',name:'Vedasandur' }],
  '008': [{ code:'001',name:'Bhavani' },{ code:'002',name:'Erode' },{ code:'003',name:'Gobichettipalayam' },{ code:'004',name:'Perundurai' },{ code:'005',name:'Sathyamangalam' }],
  '009': [{ code:'001',name:'Chinnasalem' },{ code:'002',name:'Kallakurichi' },{ code:'003',name:'Sankarapuram' },{ code:'004',name:'Tirukovilur' },{ code:'005',name:'Ulundurpet' }],
  '010': [{ code:'001',name:'Kancheepuram' },{ code:'002',name:'Sriperumbudur' },{ code:'003',name:'Uthiramerur' },{ code:'004',name:'Walajabad' }],
  '011': [{ code:'001',name:'Agastheeswaram' },{ code:'002',name:'Kallkulam' },{ code:'003',name:'Killiyoor' },{ code:'004',name:'Thiruvattar' },{ code:'005',name:'Vilavancode' }],
  '012': [{ code:'001',name:'Aravakurichi' },{ code:'002',name:'Karur' },{ code:'003',name:'Krishnarayapuram' },{ code:'004',name:'Kulithalai' },{ code:'005',name:'Manapparai' },{ code:'006',name:'Thanthoni' }],
  '013': [{ code:'001',name:'Bargur' },{ code:'002',name:'Denkanikotta' },{ code:'003',name:'Hosur' },{ code:'004',name:'Krishnagiri' },{ code:'005',name:'Pochampalli' },{ code:'006',name:'Uthangarai' },{ code:'007',name:'Veppanahalli' }],
  '014': [{ code:'001',name:'Madurai North' },{ code:'002',name:'Madurai South' },{ code:'003',name:'Melur' },{ code:'004',name:'Peraiyur' },{ code:'005',name:'Thirumangalam' },{ code:'006',name:'Usilampatti' },{ code:'007',name:'Vadipatti' }],
  '015': [{ code:'001',name:'Kuttalam' },{ code:'002',name:'Mayiladuthurai' },{ code:'003',name:'Sirkali' },{ code:'004',name:'Tharangambadi' }],
  '016': [{ code:'001',name:'Kilvelur' },{ code:'002',name:'Mayiladuthurai' },{ code:'003',name:'Nagapattinam' },{ code:'004',name:'Sirkazhi' },{ code:'005',name:'Tharangambadi' },{ code:'006',name:'Vedaranyam' }],
  '017': [{ code:'001',name:'Kolli Hills' },{ code:'002',name:'Kumarapalayam' },{ code:'003',name:'Mohanur' },{ code:'004',name:'Namakkal' },{ code:'005',name:'Paramathi-Velur' },{ code:'006',name:'Rasipuram' },{ code:'007',name:'Sendamangalam' },{ code:'008',name:'Thiruchengode' }],
  '018': [{ code:'001',name:'Coonoor' },{ code:'002',name:'Gudalur' },{ code:'003',name:'Kotagiri' },{ code:'004',name:'Ooty' },{ code:'005',name:'Panthalur' }],
  '019': [{ code:'001',name:'Alathur' },{ code:'002',name:'Perambalur' },{ code:'003',name:'Veppanthattai' }],
  '020': [{ code:'001',name:'Alangudi' },{ code:'002',name:'Arantangi' },{ code:'003',name:'Avudaiyarkoil' },{ code:'004',name:'Gandarvakkottai' },{ code:'005',name:'Illuppur' },{ code:'006',name:'Karambakudi' },{ code:'007',name:'Kulathur' },{ code:'008',name:'Manamelkudi' },{ code:'009',name:'Pudukkottai' },{ code:'010',name:'Thirumayam' },{ code:'011',name:'Viralimalai' }],
  '021': [{ code:'001',name:'Kadaladi' },{ code:'002',name:'Kamudhi' },{ code:'003',name:'Mudukulathur' },{ code:'004',name:'Paramakudi' },{ code:'005',name:'Ramanathapuram' },{ code:'006',name:'Rameswaram' },{ code:'007',name:'Tiruvadanai' }],
  '022': [{ code:'001',name:'Arcot' },{ code:'002',name:'Arakkonam' },{ code:'003',name:'Nemili' },{ code:'004',name:'Sholinghur' },{ code:'005',name:'Walajah' }],
  '023': [{ code:'001',name:'Attur' },{ code:'002',name:'Edappadi' },{ code:'003',name:'Gangavalli' },{ code:'004',name:'Mettur' },{ code:'005',name:'Omalur' },{ code:'006',name:'Salem' },{ code:'007',name:'Sangagiri' },{ code:'008',name:'Valapady' },{ code:'009',name:'Yercaud' }],
  '024': [{ code:'001',name:'Devakottai' },{ code:'002',name:'Ilayangudi' },{ code:'003',name:'Kallal' },{ code:'004',name:'Karaikudi' },{ code:'005',name:'Manamadurai' },{ code:'006',name:'Sivagangai' },{ code:'007',name:'Tiruppuvanam' }],
  '025': [{ code:'001',name:'Kadayanallur' },{ code:'002',name:'Keezhpavoor' },{ code:'003',name:'Sankarankoil' },{ code:'004',name:'Shencottah' },{ code:'005',name:'Tenkasi' },{ code:'006',name:'Vasudevanallur' }],
  '026': [{ code:'001',name:'Kumbakonam' },{ code:'002',name:'Orathanadu' },{ code:'003',name:'Papanasam' },{ code:'004',name:'Pattukkottai' },{ code:'005',name:'Peravurani' },{ code:'006',name:'Thiruvidaimarudur' },{ code:'007',name:'Thanjavur' }],
  '027': [{ code:'001',name:'Andipatti' },{ code:'002',name:'Bodinayakanur' },{ code:'003',name:'Periyakulam' },{ code:'004',name:'Theni-Allinagaram' },{ code:'005',name:'Uthamapalayam' }],
  '028': [{ code:'001',name:'Ettayapuram' },{ code:'002',name:'Kovilpatti' },{ code:'003',name:'Ottapidaram' },{ code:'004',name:'Sathankulam' },{ code:'005',name:'Srivaikundam' },{ code:'006',name:'Thoothukudi' },{ code:'007',name:'Tiruchendur' },{ code:'008',name:'Vilathikulam' }],
  '029': [{ code:'001',name:'Lalgudi' },{ code:'002',name:'Manachanallur' },{ code:'003',name:'Manapparai' },{ code:'004',name:'Marungapuri' },{ code:'005',name:'Musiri' },{ code:'006',name:'Srirangam' },{ code:'007',name:'Thottiyam' },{ code:'008',name:'Tiruchirappalli' },{ code:'009',name:'Tiruverumbur' },{ code:'010',name:'Uppiliyapuram' }],
  '030': [{ code:'001',name:'Ambasamudram' },{ code:'002',name:'Cheranmahadevi' },{ code:'003',name:'Kalakadu' },{ code:'004',name:'Manur' },{ code:'005',name:'Nanguneri' },{ code:'006',name:'Palayamkottai' },{ code:'007',name:'Sankarankoil' },{ code:'008',name:'Shencottah' },{ code:'009',name:'Tirunelveli' },{ code:'010',name:'Valliyur' }],
  '031': [{ code:'001',name:'Ambur' },{ code:'002',name:'Jolarpet' },{ code:'003',name:'Natrampalli' },{ code:'004',name:'Tirupattur' },{ code:'005',name:'Vaniyambadi' }],
  '032': [{ code:'001',name:'Avinashi' },{ code:'002',name:'Dharapuram' },{ code:'003',name:'Kangeyam' },{ code:'004',name:'Madathukulam' },{ code:'005',name:'Palladam' },{ code:'006',name:'Tiruppur' },{ code:'007',name:'Udumalaipettai' },{ code:'008',name:'Uthukuli' }],
  '033': [{ code:'001',name:'Ambattur' },{ code:'002',name:'Avadi' },{ code:'003',name:'Gummidipoondi' },{ code:'004',name:'Minjur' },{ code:'005',name:'Ponneri' },{ code:'006',name:'Poonamallee' },{ code:'007',name:'Uthukottai' }],
  '034': [{ code:'001',name:'Arni' },{ code:'002',name:'Chengam' },{ code:'003',name:'Chetpet' },{ code:'004',name:'Jawadhu Hills' },{ code:'005',name:'Kalasapakkam' },{ code:'006',name:'Kilpennathur' },{ code:'007',name:'Polur' },{ code:'008',name:'Tiruvannamalai' },{ code:'009',name:'Vandavasi' },{ code:'010',name:'Vembakkam' }],
  '035': [{ code:'001',name:'Kodavasal' },{ code:'002',name:'Mannargudi' },{ code:'003',name:'Nannilam' },{ code:'004',name:'Needamangalam' },{ code:'005',name:'Papanasam' },{ code:'006',name:'Thiruthuraipoondi' },{ code:'007',name:'Tiruvarur' }],
  '036': [{ code:'001',name:'Anaicut' },{ code:'002',name:'Gudiyatham' },{ code:'003',name:'Katpadi' },{ code:'004',name:'Pallikonda' },{ code:'005',name:'Pernambut' },{ code:'006',name:'Vellore' }],
  '037': [{ code:'001',name:'Gingee' },{ code:'002',name:'Kallakurichi' },{ code:'003',name:'Mailam' },{ code:'004',name:'Marakanam' },{ code:'005',name:'Mugaiyur' },{ code:'006',name:'Thirukoilur' },{ code:'007',name:'Tindivanam' },{ code:'008',name:'Vanur' },{ code:'009',name:'Viluppuram' }],
  '038': [{ code:'001',name:'Aruppukkottai' },{ code:'002',name:'Kariapatti' },{ code:'003',name:'Rajapalayam' },{ code:'004',name:'Sivakasi' },{ code:'005',name:'Srivilliputhur' },{ code:'006',name:'Tiruchuli' },{ code:'007',name:'Virudhunagar' },{ code:'008',name:'Vuppiliyapatti' }],
};

const PATTA_CACHE_TTL = 10 * 60 * 1000; // 10 min
// Cache stores { html, cookies, time } so session stays valid across requests
let _pattaPageCache = null;

async function getPattaPage() {
  const now = Date.now();
  if (_pattaPageCache && (now - _pattaPageCache.time) < PATTA_CACHE_TTL) {
    return _pattaPageCache;
  }
  const home = await fetchRaw(PATTA_HOME_URL, {
    headers: { Referer: PATTA_HOME_URL, 'Upgrade-Insecure-Requests': '1' },
  });
  if (home.status !== 200) throw new Error(`Patta home page returned HTTP ${home.status}`);

  const landingM  = home.body.match(/href="(land\/chittaNewRuralTamil\.html\?lan=ta&rno=[^"]+)"/i);
  const landingUrl = landingM ? `${PATTA_BASE}/eservicesnew/${landingM[1]}` : `${PATTA_BASE}${PATTA_FORM_PATH}?lan=ta`;
  const res = await fetchRaw(landingUrl, {
    headers: { Referer: PATTA_HOME_URL, 'Upgrade-Insecure-Requests': '1' },
    cookies: home.cookies,
  });
  if (res.status !== 200) throw new Error(`Patta page returned HTTP ${res.status}`);

  const cookies = res.cookies || home.cookies;

  // Load the form target page to get chkrno / ajax_rno session tokens
  const extract = await fetchRaw(`${PATTA_BASE}${PATTA_PATH}?lan=ta`, {
    headers: { Referer: landingUrl },
    cookies,
  }).catch(() => ({ body: '' }));

  const chkrno  = (extract.body.match(/(?:name|id)="chkrno"[^>]*value="([^"]+)"/i) ||
                   extract.body.match(/name="chkrno"\s+value="([^"]+)"/i) || [])[1] || '';
  const ajaxRno = (extract.body.match(/(?:name|id)="ajax_rno"[^>]*value="([^"]+)"/i) ||
                   extract.body.match(/name="ajax_rno"\s+value="([^"]+)"/i) || [])[1] || chkrno;

  const ctx = { html: res.body, cookies, time: now, url: landingUrl, chkrno, ajaxRno };
  _pattaPageCache = ctx;
  return ctx;
}

async function pattaAjax(pageCtx, query) {
  const res = await fetchRaw(`${PATTA_BASE}${PATTA_AJAX_PATH}?${query}`, {
    method: 'GET',
    cookies: pageCtx.cookies,
    headers: {
      Referer: pageCtx.url || PATTA_URL,
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  return { html: res.body, cookies: mergeCookies(pageCtx.cookies, res.cookies) };
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

// ── TNGIS (Tamil Nadu GIS) cadastral source ─────────────────────────────────────
//
// TNGIS publishes a fully public GeoServer WFS (no auth, no captcha) with a
// 6.2M-parcel cadastral layer. We query it by survey number constrained to the
// map location (lat/lon) the Market Intelligence page already has — this avoids
// the eservices↔TNGIS code-mapping problem entirely.
//
// Verified facts about this GeoServer:
//   • Layer:    cadastral_analysis:view_cadastral  (FMB sibling: view_fmb)
//   • Geometry axis order in CQL is LAT/LON (Y/X):
//       DWITHIN(the_geom, POINT(<lat> <lon>), <r>, meters)
//       BBOX(the_geom, <minLat>, <minLon>, <maxLat>, <maxLon>)
//   • Useful attributes: survey_number, sub_division, patta_no, land_type,
//     type_cate (e.g. "Poramboke"), govt_pri, ext_ares, calculated_area,
//     tax_hect, is_fmb, district_code/taluk_code/village_code.

const TNGIS_WFS = 'https://tngis.tn.gov.in/tngismaps/wfs';
const TNGIS_CADASTRAL_LAYER = 'cadastral_analysis:view_cadastral';

function tngisWfsUrl(cqlFilter, count = 25) {
  const params = new URLSearchParams({
    service:      'WFS',
    version:      '2.0.0',
    request:      'GetFeature',
    typeNames:    TNGIS_CADASTRAL_LAYER,
    outputFormat: 'application/json',
    count:        String(count),
    cql_filter:   cqlFilter,
  });
  return `${TNGIS_WFS}?${params.toString()}`;
}

// Escape single quotes for CQL string literals.
function cqlStr(v) {
  return String(v).replace(/'/g, "''");
}

// Map a TNGIS cadastral feature's attributes to the same { fields } shape the
// frontend uses for patta results. Only non-empty values are included.
function tngisFeatureToFields(props) {
  const fields = {};
  const put = (label, val) => {
    if (val !== null && val !== undefined && String(val).trim() !== '' &&
        String(val).trim() !== '-') {
      fields[label] = String(val).trim();
    }
  };
  put('Survey Number',     props.survey_number);
  put('Sub Division',      props.sub_division);
  if (props.patta_no !== null && props.patta_no !== undefined &&
      Number(props.patta_no) > 0) {
    put('Patta Number', props.patta_no);
  }
  put('Land Classification', props.type_cate);
  if (props.govt_pri !== null && props.govt_pri !== undefined) {
    const g = String(props.govt_pri).trim();
    if (g === '1') fields['Ownership Type'] = 'Government';
    else if (g === '2' || g === '0') fields['Ownership Type'] = 'Private';
  }
  put('Extent (Ares)',     props.ext_ares);
  put('Computed Area (Hectare)', props.calculated_area);
  put('Tax (Hectare)',     props.tax_hect);
  put('FMB Available',     props.is_fmb === 1 || props.is_fmb === '1' ? 'Yes' : undefined);
  put('Remarks',           props.remarks_unicode || props.remarks1_unicode);
  return fields;
}

// Query TNGIS for a survey number near a location. Returns { fields, owners }
// (owners is always [] — the public cadastral layer carries no owner names)
// or null if nothing is found.
async function fetchTngisPatta({ surveyNo, subDiv, lat, lon, radiusMeters = 5000 }) {
  const hasPoint = Number.isFinite(lat) && Number.isFinite(lon);
  const clauses = [];
  if (surveyNo) clauses.push(`survey_number='${cqlStr(surveyNo)}'`);
  if (subDiv)   clauses.push(`sub_division='${cqlStr(subDiv)}'`);
  if (hasPoint) {
    // Axis order is LAT/LON for this GeoServer.
    clauses.push(`DWITHIN(the_geom, POINT(${lat} ${lon}), ${radiusMeters}, meters)`);
  }
  if (clauses.length === 0) return null;

  const url = tngisWfsUrl(clauses.join(' AND '), surveyNo ? 25 : 5);
  const res = await fetchRaw(url, {
    headers: { Accept: 'application/json', Referer: 'https://tngis.tn.gov.in/' },
  });
  if (res.status !== 200) throw new Error(`TNGIS WFS returned HTTP ${res.status}`);

  let data;
  try { data = JSON.parse(res.body); } catch (_) { return null; }
  const features = Array.isArray(data.features) ? data.features : [];
  if (features.length === 0) return null;

  // Prefer the parcel closest to the point when several share a survey number:
  // GeoServer returns nearest-ish first for DWITHIN, so take the first feature
  // for the primary fields and list the rest as additional matching parcels.
  const primary = tngisFeatureToFields(features[0].properties || {});
  const owners = features.slice(1, 10).map(f => {
    const p = f.properties || {};
    const row = {};
    if (p.survey_number) row['Survey No'] = String(p.survey_number);
    if (p.sub_division && String(p.sub_division).trim() !== '-') {
      row['Sub Div'] = String(p.sub_division);
    }
    if (p.type_cate) row['Classification'] = String(p.type_cate);
    if (p.ext_ares !== null && p.ext_ares !== undefined) {
      row['Extent (Ares)'] = String(p.ext_ares);
    }
    return row;
  }).filter(r => Object.keys(r).length > 0);

  if (Object.keys(primary).length === 0 && owners.length === 0) return null;
  return { fields: primary, owners };
}

// ── Patta Routes ──────────────────────────────────────────────────────────────

router.get('/districts', async (req, res) => {
  try {
    const { html } = await getPattaPage();
    const districts = parseSelectOptions(html, 'districtCode')
      .filter(d => !d.name.toLowerCase().includes('select'));
    res.json(districts.length > 0 ? districts : STATIC_TN_DISTRICTS);
  } catch (_) {
    res.json(STATIC_TN_DISTRICTS);
  }
});

router.get('/taluks', (req, res) => {
  const { dc } = req.query;
  if (!dc) return res.status(400).json({ error: 'dc (districtCode) required' });
  const taluks = STATIC_TN_TALUKS[dc];
  if (!taluks) return res.status(404).json({ error: `No taluks found for district code ${dc}` });
  res.json(taluks);
});

router.get('/villages', async (req, res) => {
  const { dc, tc } = req.query;
  if (!dc || !tc) return res.status(400).json({ error: 'dc and tc required' });

  // Try live portal first (requires valid session); fall back to empty list
  try {
    const pageCtx  = await getPattaPage();
    const tcBase   = tc.split('/')[0];
    const r1 = await fetchRaw(
      `${PATTA_BASE}${PATTA_AJAX_PATH}?page=taluk&districtCode=${encodeURIComponent(dc)}`,
      { cookies: pageCtx.cookies, headers: { Referer: pageCtx.url, 'X-Requested-With': 'XMLHttpRequest' } }
    );
    const r2 = await fetchRaw(
      `${PATTA_BASE}${PATTA_AJAX_PATH}?page=village&districtCode=${encodeURIComponent(dc)}&talukCode=${encodeURIComponent(tcBase)}`,
      { cookies: mergeCookies(pageCtx.cookies, r1.cookies), headers: { Referer: pageCtx.url, 'X-Requested-With': 'XMLHttpRequest' } }
    );
    const villages = parseJsonOrSelectOptions(r2.body, 'villageCode');
    if (villages.length > 0) return res.json(villages);
  } catch (_) {}

  // Portal ajax.html is blocked for server-side requests; return empty so the UI can prompt manual entry
  res.json([]);
});

router.get('/patta', async (req, res) => {
  const { dc, tc, vc, surveyNo, subDiv, pattaNo, ownerName, viewOpt, landtype,
          lat, lon } = req.query;

  const latN = parseFloat(lat);
  const lonN = parseFloat(lon);
  const hasGps = Number.isFinite(latN) && Number.isFinite(lonN);

  // GPS-only mode: no district/taluk/village — query TNGIS directly by location.
  // A small radius (500 m) finds the parcel the pin lands on; TNGIS returns
  // survey_number, patta_no, extent, land classification etc. for that parcel.
  if (hasGps && (!dc || !tc || !vc) && !surveyNo && !pattaNo && !ownerName) {
    try {
      const tngis = await fetchTngisPatta({ lat: latN, lon: lonN, radiusMeters: 500 });
      if (tngis) return res.json({ source: 'TNGIS (tngis.tn.gov.in)', ...tngis });
      // Widen the search before giving up
      const tngisWide = await fetchTngisPatta({ lat: latN, lon: lonN, radiusMeters: 2000 });
      if (tngisWide) return res.json({ source: 'TNGIS (tngis.tn.gov.in)', ...tngisWide });
      return res.status(422).json({
        error: 'No parcel found at this GPS location in TNGIS.',
        hint:  'Tap directly on the plot boundary on the map, or enter the survey number manually.',
      });
    } catch (err) {
      return res.status(502).json({ error: err.message });
    }
  }

  if (!dc || !tc || !vc || (!surveyNo && !pattaNo && !ownerName)) {
    return res.status(400).json({ error: 'dc, tc, vc and a patta identifier are required (or set the map location for GPS lookup)' });
  }

  // TNGIS fallback: query the public GeoServer cadastral layer by survey number
  // constrained to the map location. Used when the eservices portal fails or
  // returns nothing (it blocks Vercel IPs / requires OTP for some queries).
  const tngisFallback = async () => {
    if (!surveyNo) return null;
    return fetchTngisPatta({ surveyNo, subDiv, lat: latN, lon: lonN });
  };

  try {
    const pageCtx = await getPattaPage();

    const body = encodeForm({
      [PATTA_CTRL.task]:          'chittaTam',
      [PATTA_CTRL.searchpattano]: 'no',
      [PATTA_CTRL.chkrno]:        pageCtx.chkrno  || '',
      [PATTA_CTRL.ajaxRno]:       pageCtx.ajaxRno || '',
      [PATTA_CTRL.district]:      dc,
      [PATTA_CTRL.taluk]:         tc,
      [PATTA_CTRL.village]:       vc,
      [PATTA_CTRL.viewOpt]:       viewOpt || (pattaNo ? 'pt' : 'sur'),
      [PATTA_CTRL.landtype]:      landtype || 'R',
      [PATTA_CTRL.pattaNo]:       pattaNo || '',
      [PATTA_CTRL.owner]:         ownerName || '',
      [PATTA_CTRL.surveyNo]:      surveyNo || '',
      [PATTA_CTRL.subDiv]:        subDiv || '',
      [PATTA_CTRL.mobile]:        '',
      [PATTA_CTRL.otp]:           '',
    });

    const result = await fetchRaw(`${PATTA_BASE}${PATTA_PATH}?lan=ta`, {
      method:  'POST',
      body,
      cookies: pageCtx.cookies,
      headers: {
        Referer: pageCtx.url || `${PATTA_BASE}${PATTA_FORM_PATH}?lan=ta`,
        Origin:  PATTA_BASE,
        'X-Requested-With': 'XMLHttpRequest',
      },
    });

    const parsed = result.status === 200 ? parsePattaResult(result.body) : null;
    if (parsed) {
      return res.json({ source: 'eservices.tn.gov.in', ...parsed });
    }

    // eservices returned nothing usable — try TNGIS.
    const tngis = await tngisFallback().catch(() => null);
    if (tngis) {
      return res.json({ source: 'TNGIS (tngis.tn.gov.in)', ...tngis });
    }

    return res.status(422).json({
      error: 'No patta data found on eservices or TNGIS.',
      hint:  'Verify the survey number; TNGIS also needs the map location (lat/lon).',
    });
  } catch (err) {
    // eservices threw (timeout / blocked) — try TNGIS before giving up.
    const tngis = await tngisFallback().catch(() => null);
    if (tngis) {
      return res.json({ source: 'TNGIS (tngis.tn.gov.in)', ...tngis });
    }
    res.status(502).json({ error: err.message });
  }
});

// ── EC (tnreginet.gov.in) ─────────────────────────────────────────────────────

const EC_BASE = 'https://tnreginet.gov.in';
const EC_HOME_URL = `${EC_BASE}/portal/index.jsp`;
const EC_URL  = `${EC_BASE}/portal/webHP?requestType=ApplicationRH&actionVal=openEncumbranceCertSearch&screenId=8400001&scenarioId=2&menuCode=8400010&auditUSFlag=true`;

const EC_CTRL = {
  zone:     'cmb_Zone',
  district: 'cmb_District',
  sro:      'cmb_SroName',
  village:  'multi_cmb_Village',
  surveyNo: 'multi_SurveyNo',
  subDiv:   'multi_SubDivisionNo',
  fromDate: 'txt_PeriodStartDt',
  toDate:   'txt_PeriodEndDt',
  captcha:  'txt_Captcha',
  captchaVal: 'captcha_val',
  search:   'searchDocYearWise',
};

const EC_ZONES = [
  { code: '1', name: 'North' },
  { code: '2', name: 'South' },
  { code: '3', name: 'Central' },
];

// Static EC district data keyed by zone code.
// District codes match tnreginet.gov.in's combo values (verified from the portal).
const STATIC_EC_DISTRICTS = {
  '1': [
    { code: '2',  name: 'Chennai' },
    { code: '8',  name: 'Chengalpattu' },
    { code: '9',  name: 'Kancheepuram' },
    { code: '21', name: 'Ranipet' },
    { code: '28', name: 'Tiruvallur' },
    { code: '29', name: 'Tiruvannamalai' },
    { code: '30', name: 'Vellore' },
    { code: '32', name: 'Viluppuram' },
    { code: '6',  name: 'Kallakurichi' },
    { code: '25', name: 'Tirupattur' },
  ],
  '2': [
    { code: '4',  name: 'Coimbatore' },
    { code: '7',  name: 'Dharmapuri' },
    { code: '10', name: 'Erode' },
    { code: '11', name: 'Krishnagiri' },
    { code: '14', name: 'Namakkal' },
    { code: '15', name: 'Nilgiris' },
    { code: '20', name: 'Salem' },
    { code: '26', name: 'Tiruppur' },
  ],
  '3': [
    { code: '1',  name: 'Ariyalur' },
    { code: '3',  name: 'Cuddalore' },
    { code: '5',  name: 'Dindigul' },
    { code: '12', name: 'Kanniyakumari' },
    { code: '13', name: 'Karur' },
    { code: '16', name: 'Madurai' },
    { code: '17', name: 'Mayiladuthurai' },
    { code: '18', name: 'Nagapattinam' },
    { code: '19', name: 'Perambalur' },
    { code: '22', name: 'Pudukkottai' },
    { code: '23', name: 'Ramanathapuram' },
    { code: '24', name: 'Sivagangai' },
    { code: '27', name: 'Thanjavur' },
    { code: '31', name: 'Tenkasi' },
    { code: '33', name: 'Theni' },
    { code: '34', name: 'Tiruchirappalli' },
    { code: '35', name: 'Tirunelveli' },
    { code: '36', name: 'Tiruvarur' },
    { code: '37', name: 'Thoothukudi' },
    { code: '38', name: 'Virudhunagar' },
  ],
};

let _ecPageCache = null; // { html, cookies, time }

async function getEcPage() {
  const now = Date.now();
  if (_ecPageCache && (now - _ecPageCache.time) < PATTA_CACHE_TTL) return _ecPageCache;
  const home = await fetchRaw(EC_HOME_URL, { headers: { Referer: EC_HOME_URL } });
  if (home.status !== 200) throw new Error(`EC home page returned HTTP ${home.status}`);
  const homeCsrf = (home.body.match(/name="_csrf" content="([^"]+)"/i) ||
                    home.body.match(/var\s+csrf\s*=\s*'([^']+)'/i) || [])[1] || '';
  const res = await fetchRaw(`${EC_URL}&_csrf=${homeCsrf}`, {
    cookies: home.cookies,
    headers: {
      Referer: EC_HOME_URL,
      'X-Requested-With': 'XMLHttpRequest',
    },
  });
  if (res.status !== 200) throw new Error(`EC page returned HTTP ${res.status}`);
  const csrf = (res.body.match(/var\s+csrf\s*=\s*'([^']+)'/i) ||
                res.body.match(/name="_csrf" content="([^"]+)"/i) || [])[1] || homeCsrf;
  const ctx = { html: res.body, cookies: mergeCookies(home.cookies, res.cookies), time: now, csrf };
  _ecPageCache = ctx;
  return ctx;
}

async function ecAjax(pageCtx, actionVal, comboValue) {
  const csrf = pageCtx.csrf ||
               (pageCtx.html.match(/var\s+csrf\s*=\s*'([^']+)'/i) || [])[1] ||
               (pageCtx.html.match(/name="_csrf" content="([^"]+)"/i) || [])[1] || '';
  const url = `${EC_BASE}/portal/webHP?requestType=ApplicationRH&actionVal=${actionVal}&queryType=Select&screenId=8400001&comboValue=${encodeURIComponent(comboValue)}&_csrf=${encodeURIComponent(csrf)}`;

  const res = await fetchRaw(url, {
    method: 'POST',
    cookies: pageCtx.cookies,
    headers: {
      Referer: EC_URL,
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  return { html: res.body, cookies: mergeCookies(pageCtx.cookies, res.cookies), csrf };
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
    const ctx       = await ecAjax(pageCtx, 'loadDistrictCombo', zone);
    const districts = parseJsonOrSelectOptions(ctx.html, 'cmb_District');
    if (districts.length > 0) return res.json(districts);
  } catch (_) {}

  // Fall back to static data when tnreginet is unreachable.
  const fallback = STATIC_EC_DISTRICTS[zone];
  if (fallback) return res.json(fallback);
  res.status(502).json({ error: 'Could not fetch EC districts.' });
});

router.get('/ec/sros', async (req, res) => {
  const { zone, dc } = req.query;
  if (!zone || !dc) return res.status(400).json({ error: 'zone and dc required' });

  try {
    const pageCtx   = await getEcPage();
    const afterZone = await ecAjax(pageCtx, 'loadDistrictCombo', zone);
    const afterDist = await ecAjax(afterZone, 'loadSroCombo', dc);
    const sros = parseJsonOrSelectOptions(afterDist.html, 'cmb_SroName');
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
    const csrf    = pageCtx.csrf || (pageCtx.html.match(/var\s+csrf\s*=\s*'([^']+)'/i) || [])[1] || '';

    const body = encodeForm({
      requestType:              'ApplicationRH',
      actionVal:                'searchDocYearWise',
      screenId:                 '8400001',
      divId:                    'searchComponentSection',
      isPlotFlatWise:           'false',
      _csrf:                    csrf,
      authToken:                (pageCtx.html.match(/id="authToken"[^>]*value="([^"]*)"/i) || [])[1] || '',
      formId:                   'EncumbranceCertificateForm',
      [EC_CTRL.zone]:           zone,
      [EC_CTRL.district]:       dc,
      [EC_CTRL.sro]:            sro,
      [EC_CTRL.village]:        req.query.village || '',
      [EC_CTRL.surveyNo]:       surveyNo,
      [EC_CTRL.subDiv]:         subDiv || '',
      [EC_CTRL.fromDate]:       fromDate,
      [EC_CTRL.toDate]:         toDate,
      [EC_CTRL.captcha]:        req.query.captcha || '',
      [EC_CTRL.captchaVal]:     req.query.captcha || '',
      [EC_CTRL.search]:         'Search',
    });

    const result = await fetchRaw(EC_BASE + '/portal/webHP?requestType=ApplicationRH&actionVal=searchDocYearWise&screenId=8400001&divId=searchComponentSection&isPlotFlatWise=false&_csrf=' + csrf, {
      method:  'POST',
      body,
      cookies: pageCtx.cookies,
      headers: {
        Referer: EC_URL,
        Origin:  EC_BASE,
        'X-Requested-With': 'XMLHttpRequest',
      },
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
