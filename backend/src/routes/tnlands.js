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
 *   GET /api/tnlands/tngis/parcels          — Cadastral polygons near map center (for overlay)
 *   GET /api/tnlands/tngis/parcel          — Survey/subdivision from TNGIS (Tamil Nilam GI Viewer)
 *   GET /api/tnlands/patta                 — Patta/Chitta via TNGIS Tamil Nilam (+ FMB metadata)
 *   GET /api/tnlands/fmb                   — FMB sketch PDF (TNGIS sketch_fmb, govt seal)
 *   GET /api/tnlands/tngis/ec              — Encumbrance Certificate PDF (TNGIS GI Viewer)
 *   GET /api/tnlands/ec/zones              — EC zones (static)
 *   GET /api/tnlands/ec/districts?zone=    — EC districts for a zone
 *   GET /api/tnlands/ec/sros?zone=&dc=     — SROs for a district
 *   GET /api/tnlands/ec/search             — EC encumbrance search results
 */

const express = require('express');
const https   = require('https');
const http    = require('http');
const router  = express.Router();
const {
  fetchGiLandDetails,
  fetchGiGuidelineValue,
  fetchGiCropDetails,
  fetchGiAregOwnership,
  fetchGiPattaCopy,
  fetchGiFmbSketch,
  fetchGiEncumbranceCertificate,
  mergeGiParcelCodes,
  isInvalidFmbPdfBase64,
} = require('../lib/tngisGiViewerApi');

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
      res.on('end',   () => {
        const buf = Buffer.concat(chunks);
        const isBinary = /image\//i.test(res.headers['content-type'] || '');
        resolve({
          status:  res.statusCode,
          headers: res.headers,
          body:    isBinary ? buf : buf.toString('utf8'),
          cookies: mergedCookies,
        });
      });
      res.on('error', reject);
    });

    req.setTimeout(opts.timeoutMs || 25000, () => { req.destroy(); reject(new Error('Request timed out')); });
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

const OTP_SESSION_TTL = 15 * 60 * 1000;
/** @type {Map<string, { cookies, ajaxRno, chkrno, otpGenDate, mobile, time }>} */
const _otpSessions = new Map();

function otpMobileKey(mobile) {
  return String(mobile || '').replace(/\D/g, '').slice(-10);
}

function getOtpSession(mobile) {
  const key = otpMobileKey(mobile);
  if (key.length !== 10) return null;
  const sess = _otpSessions.get(key);
  if (!sess) return null;
  if (Date.now() - sess.time > OTP_SESSION_TTL) {
    _otpSessions.delete(key);
    return null;
  }
  return sess;
}

function parseOtpSendResult(json = {}) {
  const code = String(json.statusCode ?? '');
  if (code === 'lim_exce' || code === 'limit_exe') {
    return { ok: false, error: 'Maximum OTP attempts for this number. Wait 30 minutes and retry.' };
  }
  if (code === 'mobno_fal') {
    return { ok: false, error: 'Invalid mobile number. Use a valid 10-digit Indian mobile.' };
  }
  if (code === 'true' && json.updatedate_ts) {
    return {
      ok:         true,
      otpGenDate: json.updatedate_ts,
      newToken:   json.new_tk || '',
    };
  }
  if (code === 'false') {
    return {
      ok:    false,
      error: 'Government OTP SMS service is unavailable right now. Try again in a few minutes.',
    };
  }
  return { ok: false, error: 'Unexpected OTP response from government server.' };
}

async function requestEservicesOtp(mobile, pageCtx) {
  const payload = JSON.stringify({
    mobileno: mobile,
    actionid: 'AC01',
    lan:      'ta',
    TOKEN:    pageCtx.ajaxRno || '',
  });
  const res = await fetchRaw(`${PATTA_BASE}${PATTA_AJAX_PATH}?page=otpgeneratenew`, {
    method:      'POST',
    body:        payload,
    contentType: 'application/json; charset=utf-8',
    cookies:     pageCtx.cookies,
    headers: {
      Referer:            `${PATTA_BASE}${PATTA_PATH}?lan=ta`,
      Origin:             PATTA_BASE,
      'X-Requested-With': 'XMLHttpRequest',
      Accept:             'application/json,*/*',
    },
  });
  let json;
  try { json = JSON.parse(res.body); } catch (_) {
    throw new Error('OTP service returned invalid response');
  }
  return { res, json };
}

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

  if (Object.keys(fields).length === 0 && owners.length === 0) {
    // eservices sometimes returns printable div layouts instead of tables
    const labelPat = /<(?:th|td|label|span)[^>]*>\s*([^<:]{2,60})\s*:?\s*<\/(?:th|td|label|span)>\s*<(?:td|span|div)[^>]*>([^<]+)</gi;
    let lm;
    while ((lm = labelPat.exec(html)) !== null) {
      const k = lm[1].replace(/&nbsp;/g, ' ').trim();
      const v = lm[2].replace(/&nbsp;/g, ' ').trim();
      if (k && v && !/select|otp|mobile|captcha/i.test(k)) fields[k] = v;
    }
  }

  if (Object.keys(fields).length === 0 && owners.length === 0) return null;
  return { fields, owners };
}

function parseEservicesChittaError(html) {
  const t = String(html || '');
  if (/invalid\s*otp|otp\s*expired|wrong\s*otp|தவறான\s*ஒரு\s*முறை|காலாவதி|OTP\s*பொருந்தவில்லை/i.test(t)) {
    return 'Invalid or expired OTP. Tap Send OTP again and enter the new code within 2 minutes.';
  }
  if (/no\s*record|பதிவு\s*இல்லை|விவரங்கள்\s*இல்லை|ஏதேனும்\s*பிழை/i.test(t)) {
    return 'No patta record found on eservices for this survey.';
  }
  return null;
}

function normalizeChittaHtml(body) {
  if (!body || body.length < 120) return null;
  const t = body.trim();
  if (!t.startsWith('<')) return null;
  if (eservicesResponseNeedsOtp(t)) return null;
  if (parseEservicesChittaError(t)) return null;
  return t;
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
const TNGIS_GI_VIEWER_URL =
  'https://tngis.tn.gov.in/apps/gi_viewer/map-viewer/index.html';
const TNGIS_CADASTRAL_LAYER = 'cadastral_analysis:view_cadastral';
const TNGIS_FMB_LAYER         = 'cadastral_analysis:view_fmb';

// A single WFS GetFeature that hasn't answered in 12s is effectively dead; fail
// fast so the expanding-radius ladder can move on instead of hanging 25s each.
const WFS_TIMEOUT_MS = 12000;
// The parcel route fires many sequential WFS calls; if TNGIS is slow the whole
// request can exceed Vercel's 120s function limit and return a crash page. The
// radius loops check this deadline and stop expanding, returning best-effort
// data so the caller always gets JSON well within the limit.
const PARCEL_DEADLINE_MS = 85000;
function deadlinePassed(deadline) {
  return typeof deadline === 'number' && Date.now() > deadline;
}

function tngisGiViewerUrl(lat, lon) {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return TNGIS_GI_VIEWER_URL;
  return `${TNGIS_GI_VIEWER_URL}?lat=${lat}&lon=${lon}`;
}

function ringAreaDegrees(ring) {
  if (!ring?.length) return Infinity;
  let area = 0;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    area += (ring[j][0] + ring[i][0]) * (ring[j][1] - ring[i][1]);
  }
  return Math.abs(area / 2);
}

function featureAreaDegrees(feature) {
  const rings = featureRings(feature?.geometry);
  if (!rings.length) return Infinity;
  return Math.min(...rings.map(ringAreaDegrees));
}

// Prefer the smallest containing parcel — matches Tamil Nilam plot pick on overlap.
function pickBestContainingFeature(features, lat, lon) {
  const containing = (features || []).filter((f) => featureContainsPoint(f, lat, lon));
  if (!containing.length) return null;
  if (containing.length === 1) return containing[0];
  let best = containing[0];
  let bestArea = featureAreaDegrees(best);
  for (let i = 1; i < containing.length; i++) {
    const a = featureAreaDegrees(containing[i]);
    if (a < bestArea) {
      bestArea = a;
      best = containing[i];
    }
  }
  return best;
}

function pointToSegmentDistMeters(pxLon, pxLat, axLon, axLat, bxLon, bxLat) {
  const cosLat = Math.cos(pxLat * Math.PI / 180);
  const mx = (bxLon - axLon) * cosLat * 111320;
  const my = (bxLat - axLat) * 110540;
  const lx = (pxLon - axLon) * cosLat * 111320;
  const ly = (pxLat - axLat) * 110540;
  const len2 = mx * mx + my * my;
  if (len2 === 0) return Math.hypot(lx, ly);
  let t = (lx * mx + ly * my) / len2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(lx - t * mx, ly - t * my);
}

function minDistanceToRingMeters(lat, lon, ring) {
  if (!ring?.length) return Infinity;
  let closed = ring.length;
  if (closed > 3
      && ring[0][0] === ring[closed - 1][0]
      && ring[0][1] === ring[closed - 1][1]) {
    closed -= 1;
  }
  let min = Infinity;
  for (let i = 0; i < closed; i++) {
    const j = (i + 1) % closed;
    const d = pointToSegmentDistMeters(
      lon, lat, ring[i][0], ring[i][1], ring[j][0], ring[j][1],
    );
    if (d < min) min = d;
  }
  return min;
}

function featureMinBoundaryDistanceMeters(feature, lat, lon) {
  const rings = featureRings(feature?.geometry);
  if (!rings.length) return Infinity;
  return Math.min(...rings.map((r) => minDistanceToRingMeters(lat, lon, r)));
}

// When tap is just outside a plot (OSM map), pick the nearest parcel boundary.
function pickNearestBoundaryFeature(features, lat, lon, maxMeters) {
  let best = null;
  let bestD = Infinity;
  for (const f of features || []) {
    if (featureContainsPoint(f, lat, lon)) {
      const area = featureAreaDegrees(f);
      if (!best || area < featureAreaDegrees(best)) {
        best = f;
        bestD = 0;
      }
      continue;
    }
    const d = featureMinBoundaryDistanceMeters(f, lat, lon);
    if (d < bestD) {
      bestD = d;
      best = f;
    }
  }
  if (!best || bestD > maxMeters) return null;
  return best;
}

function normalizeSurveyNo(value) {
  return String(value ?? '').trim();
}

function surveyNumberMatches(a, b) {
  return normalizeSurveyNo(a) === normalizeSurveyNo(b);
}

/** Real sub-division — TNGIS often stores it in kide (e.g. 394/15C) not sub_division. */
function resolveTngisSubDivision(props = {}) {
  const survey = normalizeSurveyNo(props.survey_number);
  const subRaw = String(props.sub_division ?? '').trim();
  if (subRaw && subRaw !== '-' && !surveyNumberMatches(subRaw, survey)) {
    return subRaw;
  }
  const kide = String(props.kide ?? '').trim();
  if (!kide || kide === '0' || !kide.includes('/')) return null;
  const parts = kide.split('/');
  const kideSurvey = normalizeSurveyNo(parts[0]);
  const kideSub = parts.slice(1).join('/').trim();
  if (!kideSub || kideSub === '-' || surveyNumberMatches(kideSub, survey)) return null;
  if (survey && kideSurvey && !surveyNumberMatches(kideSurvey, survey)) return null;
  return kideSub;
}

function filterFeaturesBySurvey(features, surveyNo, subDiv) {
  const surveyFilter = normalizeSurveyNo(surveyNo);
  if (!surveyFilter) return features || [];
  const subFilter = subDiv && normalizeSurveyNo(subDiv) !== '' && normalizeSurveyNo(subDiv) !== '-'
    ? normalizeSurveyNo(subDiv)
    : null;
  return (features || []).filter((f) => {
    const p = f.properties || {};
    if (!surveyNumberMatches(p.survey_number, surveyFilter)) return false;
    if (subFilter) {
      const featureSub = resolveTngisSubDivision(p)
        || normalizeSurveyNo(p.sub_division);
      if (normalizeSurveyNo(featureSub).toUpperCase() !== normalizeSurveyNo(subFilter).toUpperCase()) {
        return false;
      }
    }
    return true;
  });
}

function normalizeSubDivFilter(subDiv, surveyNo) {
  const survey = normalizeSurveyNo(surveyNo);
  const sub = normalizeSurveyNo(subDiv);
  if (!sub || sub === '-') return null;
  if (survey && surveyNumberMatches(sub, survey)) return null;
  return sub;
}

function buildFeaturePool(features, surveyFilter, subFilter, lat, lon) {
  if (!features?.length) return [];
  let pool = surveyFilter
    ? filterFeaturesBySurvey(features, surveyFilter, subFilter)
    : [...features];
  if (!pool.length && surveyFilter && subFilter) {
    pool = filterFeaturesBySurvey(features, surveyFilter, null);
  }
  const containing = pool.filter((f) => featureContainsPoint(f, lat, lon));
  if (containing.length) return containing;
  return pool;
}

function pickBestFromFeaturePool(pool, lat, lon) {
  if (!pool?.length) return null;
  return pickBestContainingFeature(pool, lat, lon)
    || pickNearestBoundaryFeature(pool, lat, lon, 200)
    || pool[0];
}

/** FMB sub at tap — prefer containing polygon; fall back to nearest boundary within ~120 m. */
function pickBestFmbFeatureAtPoint(features, lat, lon, maxNearestMeters = 120) {
  if (!features?.length) return null;
  const containing = features.filter((f) => featureContainsPoint(f, lat, lon));
  const bestContaining = pickBestContainingFeature(containing, lat, lon);
  if (bestContaining) return bestContaining;
  return pickNearestBoundaryFeature(features, lat, lon, maxNearestMeters);
}

async function lookupTngisParcelAtPoint({ lat, lon, surveyNo, subDiv, deadline }) {
  const surveyFilter = normalizeSurveyNo(surveyNo);
  const subFilter = normalizeSubDivFilter(subDiv, surveyFilter);

  if (surveyFilter) {
    const radii = [120, 300, 800, 2000, 5000, 10000, 25000];
    for (const radiusMeters of radii) {
      if (deadlinePassed(deadline)) break;
      const features = await fetchTngisLayerFeatures({
        layer:        TNGIS_CADASTRAL_LAYER,
        surveyNo:       surveyFilter,
        lat,
        lon,
        radiusMeters,
        count:        150,
      });
      const pool = buildFeaturePool(features, surveyFilter, subFilter, lat, lon);
      const best = pickBestFromFeaturePool(pool, lat, lon);
      if (best) return tngisHitFromFeature(best, pool, lat, lon);
    }
    // Survey requested but not found in WFS — do not return a different survey.
    return null;
  }

  const radii = [120, 250, 450, 800, 1200, 2000, 3500, 5000];
  let lastFeatures = [];
  for (const radiusMeters of radii) {
    if (deadlinePassed(deadline)) break;
    const features = await fetchTngisParcelsNear(lat, lon, radiusMeters, 500);
    if (!features.length) continue;
    lastFeatures = features;

    const pool = buildFeaturePool(features, null, null, lat, lon);
    const best = pickBestFromFeaturePool(pool, lat, lon);
    if (best && featureContainsPoint(best, lat, lon)) {
      return tngisHitFromFeature(best, features, lat, lon);
    }
  }

  if (lastFeatures.length) {
    const best = pickNearestBoundaryFeature(lastFeatures, lat, lon, 250);
    if (best) return tngisHitFromFeature(best, lastFeatures, lat, lon);
  }
  return null;
}

async function listTngisSubdivisionsAtPoint({ lat, lon, surveyNo, deadline }) {
  const surveyFilter = surveyNo ? normalizeSurveyNo(surveyNo) : null;
  const radii = [300, 800, 1500, 3000, 6000, 10000];
  const seenIds = new Set();
  let features = [];
  for (const radiusMeters of radii) {
    if (deadlinePassed(deadline)) break;
    const batch = await fetchTngisParcelsNear(lat, lon, radiusMeters, 400);
    for (const f of batch) {
      const p = f.properties || {};
      const id = f.id || `${p.survey_number}|${p.kide}|${p.sub_division}`;
      if (seenIds.has(id)) continue;
      seenIds.add(id);
      features.push(f);
    }
    if (surveyFilter) {
      const matched = features.filter((f) => surveyNumberMatches(f.properties?.survey_number, surveyFilter));
      if (matched.length >= 3) break;
    } else if (features.length >= 15) break;
  }
  if (!features.length) return [];
  const seen = new Map();
  for (const f of features) {
    const p = f.properties || {};
    const survey = normalizeSurveyNo(p.survey_number);
    if (!survey) continue;
    if (surveyFilter && !surveyNumberMatches(survey, surveyFilter)) continue;
    const sub = resolveTngisSubDivision(p);
    const key = `${survey}|${sub ?? ''}|${String(p.kide ?? '').trim()}`;
    if (seen.has(key)) continue;
    seen.set(key, {
      surveyNumber:  survey,
      subDivision:   sub,
      kide:          p.kide != null ? String(p.kide).trim() : null,
      fields:        tngisFeatureToFields(p),
      fmbAvailable:  p.is_fmb === 1 || p.is_fmb === '1'
          || (p.kide && String(p.kide).trim() !== '0' && String(p.kide).includes('/')),
      containsPoint: featureContainsPoint(f, lat, lon),
    });
  }

  const items = [...seen.values()];

  // Cadastral WFS often lists parent survey only (kide=483); FMB subs live in view_fmb.
  const anchor = items.find((i) => i.containsPoint) || items[0];
  const dc = anchor?.fields?.['District Code'] || null;
  const tc = anchor?.fields?.['Taluk Code'] || null;
  const vc = anchor?.fields?.['Village Code'] || null;
  if (surveyFilter && dc && tc && vc && Number.isFinite(lat) && Number.isFinite(lon)) {
    for (const radiusMeters of [500, 2000, 5000, 10000]) {
      if (deadlinePassed(deadline)) break;
      const cql = buildFmbLookupCql({
        surveyNo:     surveyFilter,
        districtCode: dc,
        talukCode:    tc,
        villageCode:  vc,
        lat,
        lon,
        radiusMeters,
      });
      const fmbFeatures = await queryTngisLayerFeatures(TNGIS_FMB_LAYER, cql, 50);
      for (const f of fmbFeatures) {
        const p = f.properties || {};
        if (!surveyNumberMatches(p.survey_number, surveyFilter)) continue;
        const sub = resolveTngisSubDivision(p);
        const key = `${surveyFilter}|${sub ?? ''}|${String(p.kide ?? '').trim()}`;
        const containsPoint = featureContainsPoint(f, lat, lon);
        if (seen.has(key)) {
          const prev = seen.get(key);
          if (containsPoint) prev.containsPoint = true;
          prev.fmbAvailable = true;
          if (sub && !prev.subDivision) prev.subDivision = sub;
          continue;
        }
        seen.set(key, {
          surveyNumber:  surveyFilter,
          subDivision:   sub,
          kide:          p.kide != null ? String(p.kide).trim() : null,
          fields:        tngisFeatureToFields(p),
          fmbAvailable:  true,
          containsPoint,
        });
      }
      if ([...seen.values()].some((i) => i.subDivision && i.containsPoint)) break;
    }
  }

  const merged = [...seen.values()];
  const fmbAtPoint = merged.filter((i) => i.subDivision && i.containsPoint);
  if (fmbAtPoint.length) {
    for (const item of merged) {
      if (!item.subDivision) item.containsPoint = false;
    }
  }
  merged.sort((a, b) => {
    if (a.containsPoint !== b.containsPoint) return a.containsPoint ? -1 : 1;
    const sa = a.subDivision ?? '';
    const sb = b.subDivision ?? '';
    return sa.localeCompare(sb, undefined, { numeric: true });
  });
  return merged;
}

function tngisHitFromFeature(primaryFeature, allFeatures, lat, lon) {
  const props = primaryFeature.properties || {};
  const primary = tngisFeatureToFields(props);
  const owners = (allFeatures || [])
    .filter((f) => f !== primaryFeature)
    .slice(0, 12)
    .map((f) => {
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
    })
    .filter((r) => Object.keys(r).length > 0);

  if (Object.keys(primary).length === 0 && owners.length === 0) return null;
  return {
    fields:     primary,
    owners,
    tngisProps: props,
    geometry:   primaryFeature.geometry || null,
    pickMeta:   {
      lat,
      lon,
      containsPoint: featureContainsPoint(primaryFeature, lat, lon),
    },
  };
}

function tngisLayerWfsUrl(layer, cqlFilter, count = 25) {
  const params = new URLSearchParams({
    service:      'WFS',
    version:      '2.0.0',
    request:      'GetFeature',
    typeNames:    layer,
    outputFormat: 'application/json',
    count:        String(count),
    cql_filter:   cqlFilter,
  });
  return `${TNGIS_WFS}?${params.toString()}`;
}

function tngisWfsUrl(cqlFilter, count = 25) {
  return tngisLayerWfsUrl(TNGIS_CADASTRAL_LAYER, cqlFilter, count);
}

function buildTngisCql({ surveyNo, subDiv, lat, lon, radiusMeters }) {
  const hasPoint = Number.isFinite(lat) && Number.isFinite(lon);
  const clauses = [];
  if (surveyNo) clauses.push(`survey_number='${cqlStr(surveyNo)}'`);
  // sub_division omitted from CQL — many parcels store sub only in kide (e.g. 394/15C).
  // Callers filter by resolveTngisSubDivision() in memory.
  if (hasPoint) {
    clauses.push(`DWITHIN(the_geom, POINT(${lat} ${lon}), ${radiusMeters}, meters)`);
  }
  return clauses.length > 0 ? clauses.join(' AND ') : null;
}

function buildFmbLookupCql({
  surveyNo, subDiv, districtCode, talukCode, villageCode, lat, lon, radiusMeters,
}) {
  const clauses = [];
  const survey = normalizeSurveyNo(surveyNo);
  if (survey) clauses.push(`survey_number='${cqlStr(survey)}'`);
  // sub filtered in memory via resolveTngisSubDivision (kide field).
  if (districtCode != null && String(districtCode).trim() !== '') {
    const dc = String(districtCode).trim();
    clauses.push(/^\d+$/.test(dc) ? `district_code=${dc}` : `district_code='${cqlStr(dc)}'`);
  }
  if (talukCode != null && String(talukCode).trim() !== '') {
    const tc = String(talukCode).trim();
    clauses.push(/^\d+$/.test(tc) ? `taluk_code=${tc}` : `taluk_code='${cqlStr(tc)}'`);
  }
  if (villageCode != null && String(villageCode).trim() !== '') {
    clauses.push(`village_code='${cqlStr(String(villageCode).trim())}'`);
  }
  if (Number.isFinite(lat) && Number.isFinite(lon) && radiusMeters) {
    clauses.push(`DWITHIN(the_geom, POINT(${lat} ${lon}), ${radiusMeters}, meters)`);
  }
  return clauses.length > 0 ? clauses.join(' AND ') : null;
}

async function queryTngisLayerFeatures(layer, cql, count = 25) {
  if (!cql) return [];
  const url = tngisLayerWfsUrl(layer, cql, count);
  const res = await fetchRaw(url, {
    headers: { Accept: 'application/json', Referer: 'https://tngis.tn.gov.in/' },
    timeoutMs: WFS_TIMEOUT_MS,
  });
  if (res.status !== 200) return [];
  try {
    const data = JSON.parse(res.body);
    return Array.isArray(data.features) ? data.features : [];
  } catch (_) {
    return [];
  }
}

async function queryTngisCadastralFeatures(cql, count = 25) {
  return queryTngisLayerFeatures(TNGIS_CADASTRAL_LAYER, cql, count);
}

/** Pick FMB sub-division at map point — cadastral layer often has kide without /sub. */
async function resolveFmbSubAtPoint({
  lat, lon, surveyNo, subDiv, districtCode, talukCode, villageCode, deadline,
}) {
  const survey = normalizeSurveyNo(surveyNo);
  if (!survey || !Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  const subFilter = normalizeSubDivFilter(subDiv, survey);
  const radii = [120, 300, 500, 2000, 5000, 10000];
  for (const radiusMeters of radii) {
    if (deadlinePassed(deadline)) break;
    const cql = buildFmbLookupCql({
      surveyNo: survey,
      districtCode,
      talukCode,
      villageCode,
      lat,
      lon,
      radiusMeters,
    });
    const features = await queryTngisLayerFeatures(TNGIS_FMB_LAYER, cql, 50);
    if (!features.length) continue;
    let pool = surveyFilterPool(features, survey, subFilter);
    const best = pickBestFmbFeatureAtPoint(pool, lat, lon);
    if (!best) continue;
    const props = best.properties || {};
    const sub = resolveTngisSubDivision(props);
    if (!sub) continue;
    return {
      tngisProps: props,
      subDivision: sub,
      kide: props.kide != null ? String(props.kide).trim() : null,
      containsPoint: featureContainsPoint(best, lat, lon),
    };
  }
  return null;
}

function surveyFilterPool(features, survey, subFilter) {
  if (!survey) return features || [];
  let pool = (features || []).filter((f) => surveyNumberMatches(f.properties?.survey_number, survey));
  if (subFilter) {
    pool = pool.filter((f) => {
      const p = f.properties || {};
      const featSub = resolveTngisSubDivision(p) || normalizeSurveyNo(p.sub_division);
      return normalizeSurveyNo(featSub).toUpperCase() === normalizeSurveyNo(subFilter).toUpperCase();
    });
  }
  return pool;
}

/** Resolve TNGIS props (incl. kide) for a specific survey/sub — not the map-tap parcel. */
async function fetchTngisParcelPropsForFmb(opts = {}) {
  const survey = normalizeSurveyNo(opts.surveyNo);
  if (!survey) return null;
  const sub = normalizeSubDivFilter(opts.subDiv, survey);
  const lat = opts.lat;
  const lon = opts.lon;
  const base = {
    surveyNo:     survey,
    subDiv:       sub,
    districtCode: opts.districtCode,
    talukCode:    opts.talukCode,
    villageCode:  opts.villageCode,
  };

  const pickFrom = (features) => {
    const pool = buildFeaturePool(features, survey, sub, lat, lon);
    const best = pickBestFromFeaturePool(pool, lat, lon);
    return best?.properties || null;
  };

  if (sub) {
    const cql = buildFmbLookupCql(base);
    const hit = pickFrom(await queryTngisCadastralFeatures(cql, 50));
    if (hit) return hit;
  }

  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    for (const r of [120, 500, 2000, 10000, 25000]) {
      const cql = buildFmbLookupCql({ ...base, lat, lon, radiusMeters: r });
      const hit = pickFrom(await queryTngisCadastralFeatures(cql, 50));
      if (hit) return hit;
    }
  }

  const cql = buildFmbLookupCql({
    ...base,
    lat,
    lon,
    radiusMeters: Number.isFinite(lat) ? 5000 : undefined,
  });
  if (cql) return pickFrom(await queryTngisCadastralFeatures(cql, 25));
  return null;
}

async function fetchTngisLayerFeatures({ layer, surveyNo, subDiv, lat, lon, radiusMeters = 5000, count = 5 }) {
  const cql = buildTngisCql({ surveyNo, subDiv, lat, lon, radiusMeters });
  if (!cql) return [];

  const url = tngisLayerWfsUrl(layer, cql, count);
  const res = await fetchRaw(url, {
    headers: { Accept: 'application/json', Referer: 'https://tngis.tn.gov.in/' },
    timeoutMs: WFS_TIMEOUT_MS,
  });
  if (res.status !== 200) throw new Error(`TNGIS WFS returned HTTP ${res.status}`);

  let data;
  try { data = JSON.parse(res.body); } catch (_) { return []; }
  return Array.isArray(data.features) ? data.features : [];
}

// The view_fmb layer lists parcels that have digitized FMB sketches — prefer it
// for document download when the cadastral pin lands on a nearby but different row.
async function fetchTngisFmbProps({ surveyNo, subDiv, lat, lon, districtCode, talukCode, villageCode }) {
  const survey = normalizeSurveyNo(surveyNo);
  if (survey) {
    const hit = await fetchTngisParcelPropsForFmb({
      surveyNo: survey,
      subDiv,
      districtCode,
      talukCode,
      villageCode,
      lat,
      lon,
    });
    if (hit) return hit;
  }

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const subFilter = subDiv && String(subDiv).trim() !== '' && String(subDiv).trim() !== '-'
    ? String(subDiv).trim()
    : null;

  const radii = surveyNo ? [500, 2000, 5000, 10000] : [100, 500, 2000, 5000, 10000];
  for (const r of radii) {
    const features = await fetchTngisLayerFeatures({
      layer: TNGIS_FMB_LAYER,
      surveyNo,
      subDiv: subFilter,
      lat,
      lon,
      radiusMeters: r,
      count:        surveyNo ? 50 : 5,
    });
    if (features.length === 0) continue;

    const pool = subFilter
      ? features.filter((f) => {
          const p = f.properties || {};
          if (survey && !surveyNumberMatches(p.survey_number, survey)) return false;
          const featSub = resolveTngisSubDivision(p) || normalizeSurveyNo(p.sub_division);
          return featSub === subFilter;
        })
      : features.filter((f) => {
          if (!survey) return true;
          return surveyNumberMatches(f.properties?.survey_number, survey);
        });
    const candidates = pool.length ? pool : features;
    const best = pickBestFmbFeatureAtPoint(candidates, lat, lon);
    if (best?.properties) return best.properties;
  }
  return null;
}

// Escape single quotes for CQL string literals.
function cqlStr(v) {
  return String(v).replace(/'/g, "''");
}

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const p = Math.PI / 180;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2
    + Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 2 * R * Math.asin(Math.sqrt(Math.max(0, a)));
}

function ringCentroidLonLat(ring) {
  if (!ring?.length) return null;
  let closed = ring.length;
  if (ring.length > 3
      && ring[0][0] === ring[ring.length - 1][0]
      && ring[0][1] === ring[ring.length - 1][1]) {
    closed -= 1;
  }
  let sx = 0;
  let sy = 0;
  for (let i = 0; i < closed; i++) {
    sx += ring[i][0];
    sy += ring[i][1];
  }
  return { lon: sx / closed, lat: sy / closed };
}

function pointInRing(lon, lat, ring) {
  if (!ring?.length) return false;
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const xi = ring[i][0];
    const yi = ring[i][1];
    const xj = ring[j][0];
    const yj = ring[j][1];
    const denom = (yj - yi) || 1e-15;
    const intersect = ((yi > lat) !== (yj > lat))
      && (lon < ((xj - xi) * (lat - yi)) / denom + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

function featureRings(geometry) {
  if (!geometry) return [];
  if (geometry.type === 'Polygon') return [geometry.coordinates[0]];
  if (geometry.type === 'MultiPolygon') {
    return geometry.coordinates.map((p) => p[0]).filter(Boolean);
  }
  return [];
}

function featureContainsPoint(feature, lat, lon) {
  for (const ring of featureRings(feature.geometry)) {
    if (pointInRing(lon, lat, ring)) return true;
  }
  return false;
}

function pickNearestTngisFeature(features, lat, lon) {
  if (!features?.length) return null;
  const containing = features.filter((f) => featureContainsPoint(f, lat, lon));
  const pool = containing.length > 0 ? containing : features;
  let best = null;
  let bestD = Infinity;
  for (const f of pool) {
    const rings = featureRings(f.geometry);
    const ring = rings[0];
    if (!ring) continue;
    const c = ringCentroidLonLat(ring);
    if (!c) continue;
    const d = haversineMeters(lat, lon, c.lat, c.lon);
    if (d < bestD) {
      bestD = d;
      best = f;
    }
  }
  if (!best) return null;
  return {
    feature: best,
    distanceMeters: bestD,
    containsPoint: featureContainsPoint(best, lat, lon),
  };
}

async function fetchTngisParcelsNear(lat, lon, radiusMeters, count = 150) {
  return fetchTngisLayerFeatures({
    layer:        TNGIS_CADASTRAL_LAYER,
    lat,
    lon,
    radiusMeters,
    count,
  });
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
  put('Sub Division',      resolveTngisSubDivision(props));
  put('Kide',              props.kide);
  put('District Code',     props.district_code);
  put('Taluk Code',        props.taluk_code);
  put('Village Code',      props.village_code);
  put('District',          props.district_name || props.district);
  put('Taluk',             props.taluk_name || props.taluk);
  put('Village',           props.village_name || props.village);
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
async function fetchTngisPatta({ surveyNo, subDiv, lat, lon, radiusMeters = 5000, deadline }) {
  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    const hit = await lookupTngisParcelAtPoint({
      lat,
      lon,
      surveyNo: surveyNo || undefined,
      subDiv:   subDiv   || undefined,
      deadline,
    });
    if (hit) return hit;
    if (!surveyNo) return null;
  }

  const cql = buildTngisCql({ surveyNo, subDiv, lat, lon, radiusMeters });
  if (!cql) return null;

  const url = tngisWfsUrl(cql, surveyNo ? 50 : 200);
  const res = await fetchRaw(url, {
    headers: { Accept: 'application/json', Referer: 'https://tngis.tn.gov.in/' },
    timeoutMs: WFS_TIMEOUT_MS,
  });
  if (res.status !== 200) throw new Error(`TNGIS WFS returned HTTP ${res.status}`);

  let data;
  try { data = JSON.parse(res.body); } catch (_) { return null; }
  const features = Array.isArray(data.features) ? data.features : [];
  if (features.length === 0) return null;

  let pool = features;
  const subFilter = subDiv && normalizeSurveyNo(subDiv) !== '' && normalizeSurveyNo(subDiv) !== '-'
    ? normalizeSurveyNo(subDiv)
    : null;
  if (surveyNo) {
    const matched = filterFeaturesBySurvey(features, surveyNo, subFilter);
    if (matched.length) pool = matched;
  } else if (subFilter) {
    const matched = features.filter(
      (f) => normalizeSurveyNo(f.properties?.sub_division) === subFilter,
    );
    if (matched.length) pool = matched;
  }

  const primaryFeature = pool[0];
  return tngisHitFromFeature(primaryFeature, pool, lat, lon);
}

// ── CollabLand FMB (official digitized sketch PDF) ───────────────────────────
//
// Tamil Nadu Survey Dept publishes digitized FMB sketches via CollabLand-TN.
// giscode format (verified): S + 2-digit district + taluk + 3-digit village + survey
//   e.g. district=2, taluk=11, village=010, survey=217 → S0211010217

const COLLABLAND_FMB_URL =
  'https://collabland-tn.gov.in/rest/Collabland/FMBMapServicePDF';

function padLandCode(value, width) {
  const s = String(value ?? '').trim();
  if (!s) return '';
  return s.padStart(width, '0');
}

function buildCollablandGiscode({ districtCode, talukCode, villageCode, surveyNo }) {
  // giscode is a fixed-width concatenation with no delimiters, so every field
  // must be zero-padded to its exact width: S + district(2) + taluk(2) +
  // village(3) + survey. An unpadded taluk shifts the village/survey boundaries
  // and makes CollabLand return a different parcel's sketch.
  const dc     = padLandCode(districtCode, 2);
  const tc     = padLandCode(talukCode, 2);
  const vc     = padLandCode(villageCode, 3);
  const survey = String(surveyNo ?? '').trim();
  if (!dc || !tc || !vc || !survey) return null;
  return `S${dc}${tc}${vc}${survey}`;
}

function giscodeFromTngisProps(props = {}) {
  return buildCollablandGiscode({
    districtCode: props.district_code,
    talukCode:    props.taluk_code,
    villageCode:  props.village_code,
    surveyNo:     props.survey_number,
  });
}

function eservicesCodesFromTngisProps(props = {}) {
  const dc = padLandCode(props.district_code, 3);
  const tcRaw = String(props.taluk_code ?? '').trim();
  const vc = padLandCode(props.village_code, 3);
  if (!dc || !tcRaw || !vc) return null;
  // eservices taluk combo values look like "10/Y" (code + rural/natham flag).
  const tc = `${padLandCode(tcRaw, 2)}/Y`;
  return { dc, tc, vc };
}

function giscodeCandidates(props = {}) {
  const out = [];
  const add = (dc, tc, vc, survey) => {
    const g = buildCollablandGiscode({
      districtCode: dc, talukCode: tc, villageCode: vc, surveyNo: survey,
    });
    if (g) out.push(g);
  };

  add(props.district_code, props.taluk_code, props.village_code, props.survey_number);

  return [...new Set(out)];
}

/** CollabLand plotno — TNGIS kide like "103/1A1" selects subdivision FMB, not parent survey. */
function fmbPlotnoFromProps(props = {}) {
  const explicit = String(props.plotno ?? '').trim();
  if (explicit) return explicit;

  const survey = normalizeSurveyNo(props.survey_number);
  const requestedSub = props.sub_division != null
      && normalizeSurveyNo(props.sub_division) !== ''
      && normalizeSurveyNo(props.sub_division) !== '-'
    ? normalizeSurveyNo(props.sub_division)
    : null;

  // TNGIS often echoes survey as sub (e.g. 330/330) — that is not a real subdivision.
  const effectiveSub = requestedSub && requestedSub !== survey ? requestedSub : null;

  const kide = String(props.kide ?? '').trim();
  if (kide && kide !== '0' && kide.includes('/')) {
    if (!effectiveSub) return kide;
    const kideSurvey = normalizeSurveyNo(kide.split('/')[0]);
    const kideSub = kide.split('/').slice(1).join('/');
    if (kideSub === effectiveSub && (!survey || kideSurvey === survey)) return kide;
    if (survey) return `${survey}/${effectiveSub}`;
    return kide;
  }

  if (!survey || !effectiveSub) return '';
  return `${survey}/${effectiveSub}`;
}

function fmbFileName(props = {}) {
  const plotno = fmbPlotnoFromProps(props);
  const survey = String(props.survey_number ?? 'sketch').trim();
  if (plotno) return `FMB-${plotno.replace(/\//g, '-')}.pdf`;
  return `FMB-${survey}.pdf`;
}

function fmbDownloadQuery(props = {}, ctx = {}) {
  const dc = String(props.district_code ?? ctx.districtCode ?? '').trim();
  const tc = String(props.taluk_code ?? ctx.talukCode ?? '').trim();
  const vc = String(props.village_code ?? ctx.villageCode ?? '').trim();
  const survey = String(props.survey_number ?? ctx.surveyNumber ?? '').trim();
  if (!dc || !tc || !vc || !survey) return null;
  let q = `dc=${encodeURIComponent(dc)}&tc=${encodeURIComponent(tc)}`
      + `&vc=${encodeURIComponent(vc)}&surveyNo=${encodeURIComponent(survey)}`;
  const sub = ctx.subDivision || resolveTngisSubDivision(props);
  if (sub) {
    q += `&subDiv=${encodeURIComponent(sub)}`;
  }
  const lat = ctx.lat;
  const lon = ctx.lon;
  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    q += `&lat=${lat}&lon=${lon}`;
  }
  return q;
}

function withTimeout(promise, ms, label = 'Request') {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms);
    }),
  ]);
}

/** FMB metadata for /patta — PDF streamed via GET /fmb (TNGIS sketch_fmb). */
function buildFmbDocumentMeta(props = {}, codes = {}, ctx = {}) {
  const q = fmbDownloadQuery(props, {
    districtCode: codes.districtCode,
    talukCode:    codes.talukCode,
    villageCode:  codes.villageCode,
    surveyNumber: codes.surveyNumber,
    subDivision:  codes.subDivision,
    lat:          ctx.lat,
    lon:          ctx.lon,
  });
  if (!q && !codes.surveyNumber) {
    return {
      type:      'fmb',
      source:    'TNGIS GI Viewer (sketch_fmb)',
      available: false,
      error:     'Parcel codes missing — tap directly on the land plot on the map.',
    };
  }
  return {
    type:        'fmb',
    source:      'TNGIS GI Viewer (sketch_fmb)',
    mimeType:    'application/pdf',
    fileName:    fmbFileName(props),
    downloadUrl: q ? `/api/tnlands/fmb?${q}` : null,
    available:   true,
    note:        'Official FMB sketch from TNGIS Tamil Nilam GI Viewer.',
  };
}

function aregToPattaHtml(areg, codes) {
  const land = areg.landDetail || {};
  const owners = areg.ownershipDetails || [];
  const rows = Object.entries(land)
    .filter(([, v]) => v != null && String(v).trim() !== '')
    .map(([k, v]) => `<tr><th>${escHtml(k)}</th><td>${escHtml(v)}</td></tr>`)
    .join('');
  let ownersHtml = '';
  if (Array.isArray(owners) && owners.length) {
    ownersHtml = owners.map((o) => {
      const orows = Object.entries(o || {})
        .map(([k, v]) => `<tr><th>${escHtml(k)}</th><td>${escHtml(v)}</td></tr>`)
        .join('');
      return `<table>${orows}</table>`;
    }).join('');
  }
  const body = `<table>${rows}</table>${ownersHtml ? `<div class="owners"><h2>Ownership</h2>${ownersHtml}</div>` : ''}`;
  return wrapPattaPrintHtml(
    'Patta / Chitta — Tamil Nilam',
    areg.source || 'TNGIS Tamil Nilam',
    body,
  );
}

async function fetchTngisGiDocuments(tngisProps, ctx = {}) {
  const documents = {};
  let giLand = null;
  if (Number.isFinite(ctx.lat) && Number.isFinite(ctx.lon)) {
    try {
      giLand = await fetchGiLandDetails(ctx.lat, ctx.lon);
      if (!giLand.ok) giLand = null;
    } catch (_) {}
  }
  const codes = mergeGiParcelCodes(giLand, tngisProps, ctx);

  // Resolve the sub-division at the tap point BEFORE fetching the patta. The
  // cadastral kide often lacks a /sub (and land_details may be throttled), so
  // without this the AREG query runs with an empty sub_division_number and
  // TNGIS returns the survey-level "common" patta instead of this plot's patta.
  if (Number.isFinite(ctx.lat) && Number.isFinite(ctx.lon) && codes.surveyNumber
      && !ctx.subDiv
      && (!codes.subDivision || surveyNumberMatches(codes.subDivision, codes.surveyNumber))) {
    try {
      const fmbHit = await resolveFmbSubAtPoint({
        lat:          ctx.lat,
        lon:          ctx.lon,
        surveyNo:     codes.surveyNumber,
        districtCode: codes.districtCode,
        talukCode:    codes.talukCode,
        villageCode:  codes.villageCode,
        deadline:     ctx.deadline,
      });
      if (fmbHit?.subDivision) {
        codes.subDivision = fmbHit.subDivision;
        codes.isFmb = true;
      }
    } catch (_) {}
  }

  // ── Patta: Tamil Nilam AREG + NIC pattacopy ──
  try {
    const areg = await fetchGiAregOwnership(codes);
    if (areg.ok) {
      const pattaNo = areg.landDetail?.pattaNo
        || areg.landDetail?.patta_number
        || areg.landDetail?.patta_no;
      if (pattaNo) {
        const copy = await fetchGiPattaCopy({ ...codes, pattaNumber: pattaNo });
        if (copy.ok) {
          documents.patta = {
            type:       'patta',
            source:     copy.source,
            available:  true,
            official:   true,
            pdfBase64:  copy.pdfBase64,
            mimeType:   'application/pdf',
            fileName:   copy.fileName,
            landDetail: areg.landDetail,
            ownership:  areg.ownershipDetails,
          };
        } else {
          documents.patta = {
            type:       'patta',
            source:     areg.source,
            available:  true,
            official:   false,
            html:       aregToPattaHtml(areg, codes),
            fileName:   `Patta-Survey-${codes.surveyNumber || 'record'}.html`,
            error:      copy.error,
            landDetail: areg.landDetail,
            ownership:  areg.ownershipDetails,
          };
        }
      } else {
        documents.patta = {
          type:       'patta',
          source:     areg.source,
          available:  true,
          official:   false,
          html:       aregToPattaHtml(areg, codes),
          fileName:   `Patta-Survey-${codes.surveyNumber || 'record'}.html`,
          landDetail: areg.landDetail,
          ownership:  areg.ownershipDetails,
        };
      }
    } else {
      documents.patta = {
        type:      'patta',
        source:    'TNGIS Tamil Nilam',
        available: false,
        error:     areg.error,
      };
    }
  } catch (err) {
    documents.patta = {
      type:      'patta',
      source:    'TNGIS Tamil Nilam',
      available: false,
      error:     err.message,
    };
  }

  // codes.subDivision was resolved above (before the patta) so the FMB metadata
  // points at the same specific sub-division as the patta.
  documents.fmb = buildFmbDocumentMeta(tngisProps, codes, ctx);
  return documents;
}

async function fetchCollablandFmbByGiscode(giscode, surveyNo, plotno = '') {
  const body = encodeForm({
    state:  '33',
    giscode,
    plotno: plotno || '',
    scale:  '0',
    width:  '1200',
    height: '1200',
  });

  const res = await fetchRaw(COLLABLAND_FMB_URL, {
    method:      'POST',
    body,
    contentType: 'application/x-www-form-urlencoded',
    headers:     { Referer: 'https://eservices.tn.gov.in/', Origin: 'https://eservices.tn.gov.in' },
  });

  if (res.status !== 200) {
    throw new Error(`CollabLand FMB returned HTTP ${res.status}`);
  }

  let data;
  try { data = JSON.parse(res.body); } catch (_) {
    throw new Error('CollabLand FMB returned invalid JSON');
  }

  if (!data.success) {
    return {
      type:      'fmb',
      source:    'collabland-tn.gov.in',
      giscode,
      error:     data.message || data.error || 'Digitized FMB sketch not available for this parcel',
      available: false,
    };
  }

  const pdfBase64 = typeof data.success === 'string' && data.success.length > 100
    ? String(data.success)
    : (data.data || data.pdf || data.pdfBase64 || data.PDF || null);
  if (!pdfBase64 || String(pdfBase64).length < 100) {
    return {
      type:      'fmb',
      source:    'collabland-tn.gov.in',
      giscode,
      error:     data.message || data.error || 'FMB PDF response was empty or invalid',
      available: false,
    };
  }
  const pdfStr = String(pdfBase64);
  const byteLen = Buffer.from(pdfStr, 'base64').length;
  if (byteLen < 100 || isInvalidFmbPdfBase64(pdfStr)) {
    return {
      type:      'fmb',
      source:    'collabland-tn.gov.in',
      giscode,
      error:     'FMB PDF response was empty or invalid',
      available: false,
    };
  }

  return {
    type:       'fmb',
    source:     'collabland-tn.gov.in',
    giscode,
    mimeType:   'application/pdf',
    fileName:   `FMB-${surveyNo || 'sketch'}.pdf`,
    pdfBase64:  pdfStr,
    byteLength: byteLen,
    available:  true,
  };
}

async function fetchCollablandFmbPdf(props = {}) {
  const candidates = giscodeCandidates(props);
  if (candidates.length === 0) return null;

  const plotno = fmbPlotnoFromProps(props);
  let last = null;

  for (const giscode of candidates) {
    if (plotno) {
      const subHit = await fetchCollablandFmbByGiscode(giscode, props.survey_number, plotno);
      if (subHit.available) {
        subHit.fileName = fmbFileName(props);
        const q = fmbDownloadQuery(props);
        if (q) subHit.downloadUrl = `/api/tnlands/fmb?${q}`;
        return subHit;
      }
      last = subHit;
      // Sub-division sketch missing — fall back to survey-level FMB.
      const parentHit = await fetchCollablandFmbByGiscode(giscode, props.survey_number, '');
      if (parentHit.available) {
        parentHit.fileName = fmbFileName({ ...props, sub_division: null, kide: null, plotno: '' });
        const q = fmbDownloadQuery({ ...props, sub_division: null, kide: null, plotno: '' });
        if (q) parentHit.downloadUrl = `/api/tnlands/fmb?${q}`;
        return parentHit;
      }
      last = parentHit;
      continue;
    }

    const parentHit = await fetchCollablandFmbByGiscode(giscode, props.survey_number, '');
    if (parentHit.available) {
      parentHit.fileName = fmbFileName(props);
      const q = fmbDownloadQuery(props);
      if (q) parentHit.downloadUrl = `/api/tnlands/fmb?${q}`;
      return parentHit;
    }
    last = parentHit;
  }
  return last;
}

/** TNGIS sketch_fmb `type` — urban areas need "urban" (TSLR), not rural FMB. */
function normalizeSketchFmbType(ruralUrban, props = {}) {
  const raw = String(
    ruralUrban ?? props.rural_urban ?? props.ruralUrban ?? props.land_type ?? '',
  ).trim().toLowerCase();
  if (raw.includes('urban') || raw === 'u' || raw.includes('tslr') || raw.includes('town')) {
    return 'urban';
  }
  if (raw.includes('natham') || raw.includes('nattam')) return 'natham';
  return 'rural';
}

function sketchFmbTypeCandidates(ruralUrban, props = {}) {
  const primary = normalizeSketchFmbType(ruralUrban, props);
  const alt = primary === 'rural' ? 'urban' : 'rural';
  return [...new Set([primary, alt, 'natham'])];
}

function collablandPropsFromCodes(codes, tngisProps = {}) {
  return {
    district_code:  codes.districtCode,
    taluk_code:     codes.talukCode,
    village_code:   codes.villageCode,
    survey_number:  codes.surveyNumber,
    sub_division:   codes.subDivision,
    kide:           tngisProps.kide,
  };
}

/**
 * TNGIS GI Viewer sketch_fmb only — same source as tngis.tn.gov.in GI Viewer.
 */
async function tryFmbSourcesForCodes(codes, ctx = {}) {
  const { lat, lon, tngisProps = {} } = ctx;
  let giLand = null;
  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    try {
      giLand = await fetchGiLandDetails(lat, lon);
      if (!giLand?.ok) giLand = null;
    } catch (_) {}
  }

  const ruralUrban = giLand?.ruralUrban ?? tngisProps.rural_urban;
  const types = sketchFmbTypeCandidates(ruralUrban, tngisProps);
  let lastErr = 'FMB sketch not available from TNGIS GI Viewer';

  for (const landType of types) {
    try {
      const fmb = await fetchGiFmbSketch({ ...codes, landType });
      if (fmb.ok && fmb.pdfBase64 && !isInvalidFmbPdfBase64(fmb.pdfBase64)) {
        return { ...fmb, landTypeUsed: landType };
      }
      if (fmb.error) lastErr = fmb.error;
    } catch (err) {
      lastErr = err.message;
    }
  }

  return { ok: false, error: lastErr };
}

async function fetchFmbSketchMultiSource(codes, ctx = {}) {
  const { tngisProps = {} } = ctx;
  const survey = String(codes.surveyNumber ?? '').trim();
  const sub = String(codes.subDivision ?? '').trim();
  const hasSub = sub && !surveyNumberMatches(sub, survey);
  let lastErr = 'FMB sketch not available from TNGIS';

  if (hasSub) {
    const withSub = await tryFmbSourcesForCodes(codes, ctx);
    if (withSub.ok) return { ...withSub, fmbScope: 'subdivision' };
    lastErr = withSub.error || lastErr;
  }

  if (survey) {
    const general = await tryFmbSourcesForCodes({ ...codes, subDivision: '' }, ctx);
    if (general.ok) {
      return {
        ...general,
        fmbScope: 'general',
        fileName: `FMB-${survey}.pdf`,
        note:     hasSub
          ? 'Sub-division sketch unavailable — showing general survey FMB.'
          : 'General survey FMB (no sub-division on record).',
      };
    }
    lastErr = general.error || lastErr;
  }

  const digitized = tngisProps.is_fmb === 1 || tngisProps.is_fmb === '1'
      || (tngisProps.kide && String(tngisProps.kide).includes('/'));
  if (!digitized && !hasSub) {
    lastErr = 'FMB/TSLR sketch is not digitized for this village on Tamil Nilam yet. '
        + 'Only surveyed villages with digitized maps are available online.';
  }

  return { ok: false, error: lastErr };
}

// ── Patta / Chitta document (eservices + TNGIS fallback) ─────────────────────

function escHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function wrapPattaPrintHtml(title, source, bodyHtml) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${escHtml(title)}</title>
<style>
  body{font-family:Georgia,serif;margin:24px;color:#111}
  h1{font-size:18px;color:#1B5E20;margin:0 0 4px}
  .sub{font-size:11px;color:#555;margin-bottom:16px}
  table{border-collapse:collapse;width:100%;margin:12px 0}
  th,td{border:1px solid #ccc;padding:8px 10px;text-align:left;font-size:13px}
  th{background:#e8f5e9;width:38%;font-weight:600}
  .owners{margin-top:16px}
  .foot{margin-top:20px;font-size:10px;color:#666;border-top:1px solid #ddd;padding-top:10px}
</style></head><body>
<h1>${escHtml(title)}</h1>
<p class="sub">Source: ${escHtml(source)} · Generated ${new Date().toLocaleString('en-IN')}</p>
${bodyHtml}
<p class="foot">This is an electronic copy for reference. For legal purposes, obtain a certified copy from the Tahsildar office.</p>
</body></html>`;
}

function parsedToPattaBody({ fields, owners }) {
  const fieldRows = Object.entries(fields || {})
    .map(([k, v]) => `<tr><th>${escHtml(k)}</th><td>${escHtml(v)}</td></tr>`)
    .join('');
  let ownersHtml = '';
  if (owners && owners.length > 0) {
    const blocks = owners.map((o) => {
      const rows = Object.entries(o)
        .map(([k, v]) => `<tr><th>${escHtml(k)}</th><td>${escHtml(v)}</td></tr>`)
        .join('');
      return `<table>${rows}</table>`;
    }).join('');
    ownersHtml = `<div class="owners"><h2 style="font-size:14px">Owners</h2>${blocks}</div>`;
  }
  return `<table>${fieldRows}</table>${ownersHtml}`;
}

function buildTngisPattaDocument(fields, props = {}) {
  const survey = fields['Survey Number'] || props.survey_number || '';
  const body = parsedToPattaBody({ fields, owners: [] });
  const extra = props.kide ? `<p><strong>Kide:</strong> ${escHtml(props.kide)}</p>` : '';
  const html = wrapPattaPrintHtml(
    'Patta / Chitta — Cadastral Record',
    'TNGIS (tngis.tn.gov.in)',
    body + extra
  );
  return {
    type:      'patta',
    source:    'TNGIS (tngis.tn.gov.in)',
    available: true,
    official:  false,
    html,
    fileName:  `Patta-${survey || 'record'}.html`,
    note:      'Cadastral record from TNGIS (tngis.tn.gov.in).',
  };
}

async function fetchPattaChittaDocument(docProps, codes, ctx = {}) {
  const fields = tngisFeatureToFields(docProps);
  return buildTngisPattaDocument(fields, docProps);
}

async function fetchPattaDocuments(tngisProps, ctx = {}) {
  return fetchTngisGiDocuments(tngisProps, ctx);
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

// Cadastral polygons for map overlay (Tamil Nilam style parcel boundaries).
router.get('/tngis/parcels', async (req, res) => {
  const latN = parseFloat(req.query.lat);
  const lonN = parseFloat(req.query.lon);
  const hasExplicitRadius = req.query.radius != null && String(req.query.radius).trim() !== '';
  const radiusMeters = hasExplicitRadius ? parseFloat(req.query.radius) : 600;
  const zoom = parseFloat(req.query.zoom);

  if (!Number.isFinite(latN) || !Number.isFinite(lonN)) {
    return res.status(400).json({ error: 'lat and lon required' });
  }

  let radius = Number.isFinite(radiusMeters) ? radiusMeters : 600;
  if (!hasExplicitRadius && Number.isFinite(zoom)) {
    if (zoom >= 18) radius = 280;
    else if (zoom >= 17) radius = 700;
    else if (zoom >= 16) radius = 1200;
    else if (zoom >= 15) radius = 2200;
    else radius = 4000;
  }

  try {
    const radii = [...new Set([
      radius,
      Math.round(radius * 1.6),
      1500,
      2500,
      4000,
      6000,
    ])].sort((a, b) => a - b);

    let features = [];
    let usedRadius = radius;
    for (const r of radii) {
      features = await fetchTngisParcelsNear(latN, lonN, r, 300);
      usedRadius = r;
      if (features.length >= 8 || r >= 4000) break;
    }

    return res.json({
      source:       'TNGIS Tamil Nilam GI Viewer',
      giViewerUrl:  tngisGiViewerUrl(latN, lonN),
      radiusMeters: usedRadius,
      count:        features.length,
      type:         'FeatureCollection',
      features,
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// All subdivisions for a survey near a map point (each sub has its own patta/FMB).
router.get('/tngis/subdivisions', async (req, res) => {
  const latN = parseFloat(req.query.lat);
  const lonN = parseFloat(req.query.lon);
  const { surveyNo } = req.query;

  if (!Number.isFinite(latN) || !Number.isFinite(lonN)) {
    return res.status(400).json({ error: 'lat and lon required' });
  }

  try {
    const subdivisions = await listTngisSubdivisionsAtPoint({
      lat: latN,
      lon: lonN,
      surveyNo: surveyNo || undefined,
    });
    return res.json({
      source: 'TNGIS Tamil Nilam GI Viewer',
      count:  subdivisions.length,
      subdivisions,
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// Parcel at map pin — same cadastral layer as Tamil Nilam GI Viewer (no captcha).
router.get('/tngis/parcel', async (req, res) => {
  const latN = parseFloat(req.query.lat);
  const lonN = parseFloat(req.query.lon);
  const { surveyNo, subDiv } = req.query;

  if (!Number.isFinite(latN) || !Number.isFinite(lonN)) {
    return res.status(400).json({
      error: 'lat and lon required (decimal degrees, same as GI Viewer Go To).',
      giViewerUrl: TNGIS_GI_VIEWER_URL,
    });
  }

  const deadline = Date.now() + PARCEL_DEADLINE_MS;

  try {
    let hit = await lookupTngisParcelAtPoint({
      lat: latN,
      lon: lonN,
      surveyNo,
      subDiv,
      deadline,
    });
    // Sub filter can be too strict (kide-only subs) — retry without sub, then lat/lon only.
    if (!hit && subDiv) {
      hit = await lookupTngisParcelAtPoint({
        lat: latN,
        lon: lonN,
        surveyNo,
        subDiv: null,
        deadline,
      });
    }
    if (!hit && surveyNo) {
      hit = await lookupTngisParcelAtPoint({
        lat: latN,
        lon: lonN,
        surveyNo: null,
        subDiv: null,
        deadline,
      });
    }
    const giViewerUrl = tngisGiViewerUrl(latN, lonN);

    if (!hit) {
      return res.status(404).json({
        error:       surveyNo
            ? `Survey ${surveyNo} not found at this map point in TNGIS.`
            : 'No cadastral parcel at this map point in TNGIS.',
        hint:        surveyNo
            ? 'Tap directly on the correct survey plot, or clear the survey filter and tap again.'
            : 'Zoom in and tap directly on the land plot (not the road).',
        giViewerUrl,
        source:      'TNGIS Tamil Nilam GI Viewer',
      });
    }

    const props = hit.tngisProps || {};
    const survey = hit.fields['Survey Number'] || props.survey_number || null;
    if (surveyNo && survey && !surveyNumberMatches(survey, surveyNo)) {
      return res.status(404).json({
        error:       `TNGIS returned survey ${survey} but survey ${surveyNo} was requested.`,
        hint:        'Tap directly on the correct land plot for this survey number.',
        giViewerUrl,
        source:      'TNGIS Tamil Nilam GI Viewer',
      });
    }

    // Subdivisions (WFS) and land_details (GI API) are independent — run them
    // concurrently so the slower one, not their sum, bounds the response time.
    const [subdivisions, giLand] = await Promise.all([
      listTngisSubdivisionsAtPoint({
        lat: latN,
        lon: lonN,
        surveyNo: survey || surveyNo,
        deadline,
      }).catch(() => []),
      fetchGiLandDetails(latN, lonN).catch(() => null),
    ]);

    const surveyVal = giLand?.ok && giLand.surveyNumber
      ? giLand.surveyNumber
      : survey;

    // Sub at map tap. Priority:
    //   1) rate_limit_land_details — exactly what the GI Viewer shows on click.
    //   2) view_fmb polygon containing the tap (used when land_details is throttled).
    //   3) cadastral props / requested sub.
    let subDivVal = null;
    let kideVal = props.kide != null ? String(props.kide).trim() : null;

    if (giLand?.ok && giLand.subDivision) {
      const giSub = String(giLand.subDivision).trim();
      if (giSub && giSub !== '-' && !surveyNumberMatches(giSub, surveyVal)) {
        subDivVal = giSub;
        if (!kideVal || !kideVal.includes('/')) kideVal = `${surveyVal}/${giSub}`;
      }
    }

    if (!subDivVal) {
      const containingSub = subdivisions.find((s) => s.containsPoint && s.subDivision);
      if (containingSub?.subDivision) {
        subDivVal = containingSub.subDivision;
        if (containingSub.kide) kideVal = containingSub.kide;
      } else {
        try {
          const fmbHit = await resolveFmbSubAtPoint({
            lat:          latN,
            lon:          lonN,
            surveyNo:     surveyVal,
            districtCode: props.district_code,
            talukCode:    props.taluk_code,
            villageCode:  props.village_code,
            deadline,
          });
          if (fmbHit?.subDivision) {
            subDivVal = fmbHit.subDivision;
            if (fmbHit.kide) kideVal = fmbHit.kide;
          }
        } catch (_) {}
      }
    }

    if (!subDivVal) {
      subDivVal = resolveTngisSubDivision(props)
        || normalizeSubDivFilter(req.query.subDiv, surveyVal)
        || (hit.fields['Sub Division'] && !surveyNumberMatches(hit.fields['Sub Division'], surveyVal)
            ? hit.fields['Sub Division']
            : null);
    }

    if (subDivVal) hit.fields['Sub Division'] = subDivVal;
    if (kideVal) hit.fields['Kide'] = kideVal;

    const fmbAvailable = props.is_fmb === 1 || props.is_fmb === '1'
        || (kideVal && kideVal.includes('/'))
        || subdivisions.some((s) => s.fmbAvailable);

    const fmbNote = fmbAvailable
      ? 'Digitized FMB/TSLR sketch available from Tamil Nilam'
      : 'FMB/TSLR sketch may not be digitized for this village yet — online coverage is limited across Tamil Nadu';

    return res.json({
      source:       'TNGIS Tamil Nilam GI Viewer',
      giViewerUrl,
      fields:       hit.fields,
      owners:       hit.owners,
      surveyNumber: surveyVal,
      subDivision:  subDivVal,
      ulpin:        giLand?.ok ? (giLand.ulpin || null) : null,
      centroid:     giLand?.ok
          ? (giLand.centroid || `${latN}, ${lonN}`)
          : `${latN}, ${lonN}`,
      kide:         kideVal,
      district:     hit.fields.District || props.district_name || null,
      taluk:        hit.fields.Taluk || props.taluk_name || null,
      village:      hit.fields.Village || props.village_name || null,
      pattaNumber:  hit.fields['Patta Number'] || props.patta_no || null,
      // rural = FMB (survey no + sub-division); urban = TSLR (T.S. no + block).
      ruralUrban:   (giLand?.ok ? giLand.ruralUrban : null) || props.rural_urban || null,
      fmbAvailable,
      fmbNote,
      containsPoint: hit.pickMeta?.containsPoint ?? false,
      distanceMeters: hit.pickMeta?.containsPoint ? 0 : undefined,
      subdivisions,
      giServices: buildGiServiceCards(props, hit.fields, giLand),
      giLandError: giLand?.ok ? null : (giLand?.error || null),
    });
  } catch (err) {
    return res.status(502).json({
      error:       err.message,
      giViewerUrl: tngisGiViewerUrl(latN, lonN),
    });
  }
});

function buildGiServiceCards(props = {}, fields = {}, giLand = null) {
  const survey = String(giLand?.surveyNumber || fields['Survey Number'] || props.survey_number || '').trim();
  const sub = String(giLand?.subDivision || fields['Sub Division'] || props.sub_division || '').trim();
  const pattaNo = String(fields['Patta Number'] || props.patta_no || '').trim();
  const landType = String(fields['Land Classification'] || props.type_cate || props.land_type || '').trim();
  const fmbAvail = props.is_fmb === 1 || props.is_fmb === '1'
      || (props.kide && String(props.kide).trim() !== '0' && String(props.kide).includes('/'));

  return {
    patta: {
      id: 'patta', title: 'Patta', available: Boolean(survey),
      summary: pattaNo ? `Patta ${pattaNo}` : (survey ? `Survey ${survey}${sub && sub !== survey ? ` / ${sub}` : ''}` : 'Tap a plot on the map'),
    },
    fmb: {
      id: 'fmb', title: 'FMB', available: fmbAvail || Boolean(survey),
      summary: fmbAvail ? 'Digitized FMB sketch' : 'Field Measurement Book',
    },
    ec: {
      id: 'ec', title: 'EC', available: Boolean(survey),
      summary: 'Encumbrance Certificate',
    },
    gvalue: {
      id: 'gvalue', title: 'G-Value', available: Boolean(survey),
      summary: landType || 'Guideline value',
    },
    crop: {
      id: 'crop', title: 'Crop', available: Boolean(survey),
      summary: landType || 'Crop survey',
    },
  };
}

router.get('/tngis/gi-detail', async (req, res) => {
  const latN = parseFloat(req.query.lat);
  const lonN = parseFloat(req.query.lon);
  const { surveyNo, subDiv, type } = req.query;

  if (!Number.isFinite(latN) || !Number.isFinite(lonN)) {
    return res.status(400).json({ error: 'lat and lon required' });
  }
  if (!type || !['gvalue', 'crop'].includes(String(type))) {
    return res.status(400).json({ error: 'type must be gvalue or crop' });
  }

  const giViewerUrl = tngisGiViewerUrl(latN, lonN);
  const base = { giViewerUrl, surveyNumber: surveyNo || null, subDivision: subDiv || null };

  try {
    if (type === 'gvalue') {
      const result = await fetchGiGuidelineValue(latN, lonN);
      if (!result.ok) {
        return res.status(404).json({ error: result.error, ...base, type: 'gvalue' });
      }
      return res.json({ ...base, type: 'gvalue', ...result });
    }

    const result = await fetchGiCropDetails(latN, lonN);
    if (!result.ok) {
      return res.status(404).json({ error: 'No crop data available for this parcel.', ...base, type: 'crop' });
    }
    return res.json({ ...base, type: 'crop', ...result });
  } catch (err) {
    return res.status(502).json({ error: err.message, ...base });
  }
});

router.get('/patta', async (req, res) => {
  const { dc, tc, vc, surveyNo, subDiv, pattaNo, ownerName, viewOpt, landtype,
          lat, lon, mobile, otp } = req.query;

  const latN = parseFloat(lat);
  const lonN = parseFloat(lon);
  const hasGps = Number.isFinite(latN) && Number.isFinite(lonN);
  // Same guard as /tngis/parcel: bound total TNGIS time so the patta route
  // returns JSON before Vercel's 120s function limit (was returning 504s).
  const deadline = Date.now() + PARCEL_DEADLINE_MS;
  const docCtx = {
    lat:      hasGps ? latN : undefined,
    lon:      hasGps ? lonN : undefined,
    surveyNo,
    subDiv,
    mobile:   mobile || '',
    otp:      otp || '',
    deadline,
  };

  const tryTngis = async () => {
    const radii = hasGps
        ? (surveyNo ? [500, 2000, 5000, 10000] : [100, 500, 2000, 5000, 10000])
        : [null];
    for (const r of radii) {
      if (deadlinePassed(deadline)) break;
      const hit = await fetchTngisPatta({
        surveyNo: surveyNo || undefined,
        subDiv:   subDiv   || undefined,
        lat:      hasGps ? latN : undefined,
        lon:      hasGps ? lonN : undefined,
        radiusMeters: r || 5000,
        deadline,
      });
      if (hit) return hit;
    }
    return null;
  };

  // ── 1. TNGIS (tngis.tn.gov.in) — public cadastral / patta parcel data ─────
  if (hasGps || surveyNo) {
    try {
      const tngis = await tryTngis();
      if (tngis) {
        const gotSurvey = tngis.fields?.['Survey Number'] || tngis.tngisProps?.survey_number;
        if (surveyNo && gotSurvey && !surveyNumberMatches(gotSurvey, surveyNo)) {
          return res.status(404).json({
            error: `Survey ${surveyNo} not found at this location (nearest parcel is survey ${gotSurvey}).`,
            hint:  'Tap directly on the correct survey plot on the map, then fetch again.',
          });
        }
        const { tngisProps, ...payload } = tngis;
        let documents = {};
        if (tngisProps && Object.keys(tngisProps).length > 0) {
          documents = await fetchPattaDocuments(tngisProps, docCtx);
        }
        return res.json({
          source: 'TNGIS (tngis.tn.gov.in)',
          ...payload,
          documents,
        });
      }
    } catch (err) {
      if (!dc || !tc || !vc) {
        return res.status(502).json({ error: `TNGIS lookup failed: ${err.message}` });
      }
    }
  }

  const canTryEservices = dc && tc && vc && (surveyNo || pattaNo || ownerName);
  if (!canTryEservices) {
    if (hasGps || surveyNo) {
      return res.status(422).json({
        error: surveyNo
            ? `Survey ${surveyNo} not found at this map location in TNGIS.`
            : (hasGps
                ? 'No parcel found at this map location in TNGIS.'
                : `No record found for survey number "${surveyNo}" in TNGIS.`),
        hint:  hasGps
            ? 'Tap directly on the land parcel for the correct survey number, then try again.'
            : 'Set a map location for this survey number, or use manual District/Taluk/Village.',
      });
    }
    return res.status(400).json({
      error: 'Set a map location and tap Fetch Patta, or provide district/taluk/village + survey number.',
    });
  }

  // ── 2. eservices.tn.gov.in (official Chitta extract) ────────────────────
  const tngisFallback = async () => {
    if (!surveyNo && !hasGps) return null;
    return tryTngis();
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
      const documents = {
        chittaHtml: {
          type:     'chitta',
          source:   'eservices.tn.gov.in',
          html:     result.body,
          available: true,
        },
      };
      return res.json({ source: 'eservices.tn.gov.in', ...parsed, documents });
    }

    // eservices returned nothing usable — try TNGIS.
    const tngis = await tngisFallback().catch(() => null);
    if (tngis) {
      const { tngisProps, ...payload } = tngis;
      let documents = {};
      if (tngisProps && Object.keys(tngisProps).length > 0) {
        documents = await fetchPattaDocuments(tngisProps, docCtx);
      }
      return res.json({ source: 'TNGIS (tngis.tn.gov.in)', ...payload, documents });
    }

    return res.status(422).json({
      error: 'No patta data found on eservices or TNGIS.',
      hint:  'Verify the survey number; TNGIS also needs the map location (lat/lon).',
    });
  } catch (err) {
    // eservices threw (timeout / blocked) — try TNGIS before giving up.
    const tngis = await tngisFallback().catch(() => null);
    if (tngis) {
      const { tngisProps, ...payload } = tngis;
      let documents = {};
      if (tngisProps && Object.keys(tngisProps).length > 0) {
        documents = await fetchPattaDocuments(tngisProps, docCtx);
      }
      return res.json({ source: 'TNGIS (tngis.tn.gov.in)', ...payload, documents });
    }
    res.status(502).json({ error: err.message });
  }
});

function sendFmbPdfResponse(res, fmb) {
  if (isInvalidFmbPdfBase64(fmb.pdfBase64)) {
    return res.status(404).json({
      error: 'FMB sketch not available — survey/sub-division not found in this village FMB sheet.',
      hint:  'Try tapping the exact parcel on the map or use general survey FMB.',
    });
  }
  const pdf = Buffer.from(fmb.pdfBase64, 'base64');
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fmb.fileName || 'FMB.pdf'}"`);
  res.setHeader('Content-Length', pdf.length);
  return res.send(pdf);
}

// Stream FMB PDF — TNGIS GI Viewer sketch_fmb (official sketch with govt seal).
router.get('/fmb', async (req, res) => {
  const { dc, tc, vc, surveyNo, subDiv, lat, lon, kide } = req.query;
  const latN = parseFloat(lat);
  const lonN = parseFloat(lon);
  const surveyReq = normalizeSurveyNo(surveyNo);
  const subReq = normalizeSubDivFilter(subDiv, surveyReq);
  const hasPoint = Number.isFinite(latN) && Number.isFinite(lonN);

  const codes = {
    districtCode: dc || null,
    talukCode:    tc || null,
    villageCode:  vc || null,
    surveyNumber: surveyReq || null,
    subDivision:  subReq || '',
    landType:     'rural',
    isFmb:        true,
  };

  // Bound TNGIS resolution time like /tngis/parcel and /patta so the FMB route
  // can't hang past Vercel's 120s limit.
  const deadline = Date.now() + PARCEL_DEADLINE_MS;
  let tngisProps = null;

  async function finalizeAndFetchFmb() {
    if (codes.subDivision && surveyNumberMatches(codes.subDivision, codes.surveyNumber)) {
      codes.subDivision = '';
    }
    const fmb = await fetchFmbSketchMultiSource(codes, {
      lat: hasPoint ? latN : undefined,
      lon: hasPoint ? lonN : undefined,
      tngisProps: tngisProps || {},
    });
    if (fmb.ok && fmb.pdfBase64) return sendFmbPdfResponse(res, fmb);
    return res.status(404).json({
      error:        fmb.error || 'FMB sketch not available from TNGIS for this parcel',
      surveyNumber: codes.surveyNumber,
      subDivision:  codes.subDivision || null,
      source:       'TNGIS GI Viewer (sketch_fmb)',
      hint:         'FMB/TSLR sketches are only available for villages digitized on Tamil Nilam. Rural FMB and urban TSLR coverage varies by district.',
      fmbScope:     fmb.fmbScope,
    });
  }

  // Cadastral hit — admin codes + base props from map point.
  if (hasPoint) {
    try {
      const hit = await lookupTngisParcelAtPoint({
        lat: latN,
        lon: lonN,
        surveyNo: surveyReq || undefined,
        subDiv:   subReq || undefined,
        deadline,
      });
      if (hit?.tngisProps) {
        tngisProps = { ...hit.tngisProps };
        codes.districtCode = codes.districtCode || tngisProps.district_code;
        codes.talukCode = codes.talukCode || tngisProps.taluk_code;
        codes.villageCode = codes.villageCode || tngisProps.village_code;
        codes.surveyNumber = codes.surveyNumber || tngisProps.survey_number;
      }
    } catch (_) {}
  }

  if (!tngisProps && surveyReq) {
    try {
      const props = await fetchTngisParcelPropsForFmb({
        surveyNo:     surveyReq,
        subDiv:       subReq,
        districtCode: codes.districtCode || undefined,
        talukCode:    codes.talukCode || undefined,
        villageCode:  codes.villageCode || undefined,
        lat:          hasPoint ? latN : undefined,
        lon:          hasPoint ? lonN : undefined,
      });
      if (props) {
        tngisProps = { ...props };
        codes.districtCode = codes.districtCode || props.district_code;
        codes.talukCode = codes.talukCode || props.taluk_code;
        codes.villageCode = codes.villageCode || props.village_code;
        codes.surveyNumber = codes.surveyNumber || props.survey_number;
      }
    } catch (_) {}
  }

  if (kide && String(kide).trim()) {
    tngisProps = { ...(tngisProps || {}), kide: String(kide).trim() };
  }

  // view_fmb polygon at tap — fills sub + kide for TNGIS sketch_fmb.
  // If the caller passed an explicit subDiv (the value /parcel already resolved
  // and displayed), trust it and only use view_fmb to recover the kide — never
  // override the requested sub, so the FMB matches the shown survey/sub.
  if (hasPoint && codes.surveyNumber
      && codes.districtCode && codes.talukCode && codes.villageCode) {
    try {
      const fmbHit = await resolveFmbSubAtPoint({
        lat:          latN,
        lon:          lonN,
        surveyNo:     codes.surveyNumber,
        subDiv:       subReq || codes.subDivision || undefined,
        districtCode: codes.districtCode,
        talukCode:    codes.talukCode,
        villageCode:  codes.villageCode,
        deadline,
      });
      // When the view_fmb polygon actually contains the tap point, it is the
      // exact parcel the user clicked — adopt its OWN survey + sub + admin codes
      // together so sketch_fmb gets one internally-consistent record and returns
      // this plot's sketch, not the general survey sheet. Respect an explicit
      // subReq (a sub the user picked) over the geometry.
      if (fmbHit?.containsPoint && fmbHit.tngisProps) {
        const fp = fmbHit.tngisProps;
        codes.districtCode = fp.district_code || codes.districtCode;
        codes.talukCode    = fp.taluk_code    || codes.talukCode;
        codes.villageCode  = fp.village_code  || codes.villageCode;
        codes.surveyNumber = fp.survey_number || codes.surveyNumber;
        if (!subReq && fmbHit.subDivision) codes.subDivision = fmbHit.subDivision;
      } else if (fmbHit?.subDivision && !subReq && !codes.subDivision) {
        codes.subDivision = fmbHit.subDivision;
      }
      if (fmbHit?.kide) tngisProps = { ...(tngisProps || {}), kide: fmbHit.kide };
      if (fmbHit?.tngisProps) {
        tngisProps = { ...(tngisProps || {}), ...fmbHit.tngisProps, kide: fmbHit.kide || tngisProps?.kide };
      }
    } catch (_) {}
  }

  if (subReq && !codes.subDivision) {
    codes.subDivision = subReq;
  } else if (!codes.subDivision) {
    const propsSub = resolveTngisSubDivision(tngisProps || {});
    if (propsSub) codes.subDivision = propsSub;
  }

  if (!codes.subDivision && hasPoint && codes.surveyNumber) {
    try {
      const subs = await listTngisSubdivisionsAtPoint({
        lat: latN,
        lon: lonN,
        surveyNo: codes.surveyNumber,
        deadline,
      });
      const containing = subs.find((s) => s.containsPoint && s.subDivision);
      if (containing?.subDivision) {
        codes.subDivision = containing.subDivision;
        if (containing.kide) tngisProps = { ...(tngisProps || {}), kide: containing.kide };
      }
    } catch (_) {}
  }

  if (!codes.districtCode || !codes.talukCode || !codes.villageCode || !codes.surveyNumber) {
    return res.status(400).json({
      error: 'Provide dc, tc, vc, surveyNo or lat/lon with a TNGIS parcel hit.',
    });
  }

  if (surveyReq && tngisProps?.survey_number
      && !surveyNumberMatches(tngisProps.survey_number, surveyReq)) {
    return res.status(404).json({
      error: `Survey ${surveyReq} not found for FMB lookup.`,
    });
  }

  if (!codes.subDivision) codes.subDivision = '';

  // GI Viewer land_details — authoritative village/survey codes at map point.
  if (hasPoint) {
    try {
      const giLand = await fetchGiLandDetails(latN, lonN);
      if (giLand?.ok) {
        const merged = mergeGiParcelCodes(giLand, tngisProps || {}, {
          surveyNo: codes.surveyNumber || surveyReq,
          subDiv:   codes.subDivision || subReq || undefined,
        });
        codes.districtCode = merged.districtCode || codes.districtCode;
        codes.talukCode = merged.talukCode || codes.talukCode;
        codes.villageCode = merged.villageCode || codes.villageCode;
        codes.surveyNumber = merged.surveyNumber || codes.surveyNumber;
        if (merged.subDivision) codes.subDivision = merged.subDivision;
        tngisProps = {
          ...(tngisProps || {}),
          district_code:  merged.districtCode,
          taluk_code:     merged.talukCode,
          village_code:   merged.villageCode,
          survey_number:  merged.surveyNumber,
          sub_division:   merged.subDivision,
          kide:           tngisProps?.kide,
          rural_urban:    giLand.ruralUrban || tngisProps?.rural_urban,
          is_fmb:         giLand.isFmb ?? tngisProps?.is_fmb,
        };
      }
    } catch (_) {}
  }

  try {
    return await finalizeAndFetchFmb();
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

// Encumbrance Certificate — TNGIS GI Viewer encumbrance_certificate API.
router.get('/tngis/ec', async (req, res) => {
  const latN = parseFloat(req.query.lat);
  const lonN = parseFloat(req.query.lon);
  const { surveyNo, subDiv } = req.query;

  if (!Number.isFinite(latN) || !Number.isFinite(lonN)) {
    return res.status(400).json({ error: 'lat and lon required' });
  }

  let tngisProps = null;
  try {
    const hit = await lookupTngisParcelAtPoint({
      lat: latN, lon: lonN, surveyNo, subDiv,
    });
    tngisProps = hit?.tngisProps || null;
  } catch (_) {}

  let giLand = null;
  try {
    giLand = await fetchGiLandDetails(latN, lonN);
    if (!giLand.ok) giLand = null;
  } catch (_) {}

  const codes = mergeGiParcelCodes(giLand, tngisProps || {}, { surveyNo, subDiv });
  if (!codes.districtCode || !codes.talukCode || !codes.villageCode || !codes.surveyNumber) {
    return res.status(404).json({
      error: 'Could not resolve district/taluk/village/survey from TNGIS for this plot.',
      giViewerUrl: tngisGiViewerUrl(latN, lonN),
    });
  }

  try {
    const ec = await fetchGiEncumbranceCertificate(codes);
    if (!ec.ok) {
      return res.status(404).json({
        error: ec.error,
        source: 'TNGIS GI Viewer',
        giViewerUrl: tngisGiViewerUrl(latN, lonN),
      });
    }
    return res.json({
      source: ec.source,
      giViewerUrl: tngisGiViewerUrl(latN, lonN),
      surveyNumber: codes.surveyNumber,
      subDivision: codes.subDivision || null,
      document: {
        pdfBase64: ec.pdfBase64,
        pdfFileName: ec.fileName,
        mimeType: 'application/pdf',
      },
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
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

const EC_ZONES_LEGACY = [
  { code: '1', name: 'North' },
  { code: '2', name: 'South' },
  { code: '3', name: 'Central' },
];

// Live tnreginet uses registration zones (Chennai, Coimbatore, …) — loaded from portal.
const EC_SESSION_TTL_MS = 5 * 60 * 1000;
const _ecSessions = new Map(); // sessionId → { cookies, csrf, time }

// Static fallback when portal is unreachable (subset).
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

// Fallback SRO lists when tnreginet combo API is unreachable.
const STATIC_EC_SROS = {
  '2':  [ // Chennai
    { code: '1', name: 'Adambakkam' }, { code: '5', name: 'Egmore' },
    { code: '6', name: 'Guindy' }, { code: '11', name: 'Mylapore' },
    { code: '15', name: 'Purasawalkam' }, { code: '17', name: 'Sholinganallur' },
    { code: '18', name: 'T.Nagar' }, { code: '20', name: 'Velachery' },
  ],
  '8':  [{ code: '4', name: 'Tambaram' }, { code: '1', name: 'Chengalpattu' }],
  '28': [{ code: '1', name: 'Tiruvallur' }, { code: '2', name: 'Avadi' }],
  '16': [{ code: '1', name: 'Madurai North' }, { code: '2', name: 'Madurai South' }],
  '4':  [{ code: '1', name: 'Coimbatore North' }, { code: '2', name: 'Coimbatore South' }],
};

/** Map coordinates → tnreginet zone + sub-district (registration office grouping). */
const TN_COORD_HINTS = [
  { zone: '1', dc: '20001', label: 'South Chennai', latMin: 12.85, latMax: 13.04, lonMin: 80.15, lonMax: 80.35 },
  { zone: '1', dc: '20003', label: 'Central Chennai', latMin: 13.04, latMax: 13.12, lonMin: 80.20, lonMax: 80.32 },
  { zone: '1', dc: '20002', label: 'North Chennai', latMin: 13.08, latMax: 13.28, lonMin: 80.10, lonMax: 80.22 },
  { zone: '1', dc: '50003', label: 'Tiruvallur', latMin: 13.05, latMax: 13.45, lonMin: 79.85, lonMax: 80.12 },
  { zone: '15', dc: null, label: 'Chengalpattu', latMin: 12.55, latMax: 12.95, lonMin: 79.95, lonMax: 80.35 },
  { zone: '2', dc: null, label: 'Coimbatore', latMin: 10.85, latMax: 11.25, lonMin: 76.85, lonMax: 77.15 },
  { zone: '4', dc: null, label: 'Madurai', latMin: 9.80, latMax: 10.15, lonMin: 77.95, lonMax: 78.30 },
  { zone: '5', dc: null, label: 'Salem', latMin: 11.55, latMax: 11.75, lonMin: 78.05, lonMax: 78.30 },
  { zone: '6', dc: null, label: 'Tiruchirappalli', latMin: 10.70, latMax: 10.90, lonMin: 78.60, lonMax: 78.80 },
  { zone: '7', dc: null, label: 'Thanjavur', latMin: 10.65, latMax: 10.90, lonMin: 79.05, lonMax: 79.30 },
  { zone: '8', dc: null, label: 'Tirunelveli', latMin: 8.55, latMax: 8.85, lonMin: 77.55, lonMax: 77.80 },
];

function normalizeDistrictName(name) {
  return String(name ?? '')
    .replace(/\s+district$/i, '')
    .replace(/\s+corporation$/i, '')
    .trim()
    .toLowerCase();
}

function matchEcDistrict(districts, query) {
  if (!query || !districts?.length) return null;
  const q = normalizeDistrictName(query);
  for (const d of districts) {
    if (normalizeDistrictName(d.name) === q) return d;
  }
  for (const d of districts) {
    const n = normalizeDistrictName(d.name);
    if (n.includes(q) || q.includes(n)) return d;
  }
  const tokens = q.split(/[\s\-,/]+/).filter((t) => t.length > 2);
  for (const d of districts) {
    const n = normalizeDistrictName(d.name);
    if (tokens.some((t) => n.includes(t))) return d;
  }
  return null;
}

function coordDistrictHint(lat, lon) {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  for (const h of TN_COORD_HINTS) {
    if (lat >= h.latMin && lat <= h.latMax && lon >= h.lonMin && lon <= h.lonMax) {
      return h;
    }
  }
  return null;
}

function pruneEcSessions() {
  const now = Date.now();
  for (const [id, s] of _ecSessions) {
    if (now - s.time > EC_SESSION_TTL_MS) _ecSessions.delete(id);
  }
}

function getEcSession(sessionId) {
  pruneEcSessions();
  const s = _ecSessions.get(sessionId);
  if (!s) return null;
  if (Date.now() - s.time > EC_SESSION_TTL_MS) {
    _ecSessions.delete(sessionId);
    return null;
  }
  return s;
}

function touchEcSession(sessionId, { cookies, csrf, html } = {}) {
  const s = getEcSession(sessionId);
  if (!s) return null;
  if (cookies) s.cookies = cookies;
  if (csrf) s.csrf = csrf;
  if (html) s.html = html;
  s.time = Date.now();
  _ecSessions.set(sessionId, s);
  return s;
}

async function createEcSession() {
  pruneEcSessions();
  const home = await fetchRaw(EC_HOME_URL, { headers: { Referer: EC_HOME_URL } });
  if (home.status !== 200) throw new Error(`EC home page returned HTTP ${home.status}`);
  const homeCsrf = (home.body.match(/name="_csrf" content="([^"]+)"/i) ||
                    home.body.match(/var\s+csrf\s*=\s*'([^']+)'/i) || [])[1] || '';
  const pageRes = await fetchRaw(`${EC_URL}&_csrf=${homeCsrf}`, {
    cookies: home.cookies,
    headers: { Referer: EC_HOME_URL, 'X-Requested-With': 'XMLHttpRequest' },
  });
  if (pageRes.status !== 200) throw new Error(`EC page returned HTTP ${pageRes.status}`);
  const csrf = (pageRes.body.match(/var\s+csrf\s*=\s*'([^']+)'/i) ||
                pageRes.body.match(/name="_csrf" content="([^"]+)"/i) || [])[1] || homeCsrf;
  let cookies = mergeCookies(home.cookies, pageRes.cookies);
  const capRes = await fetchRaw(`${EC_BASE}/portal/SimpleCaptcha?${Date.now()}`, {
    cookies,
    headers: { Referer: EC_URL, Accept: 'image/png,*/*' },
  });
  if (capRes.status !== 200) throw new Error('Could not load EC captcha image.');
  // Captcha image is bound to session cookies set by SimpleCaptcha — must keep them.
  cookies = mergeCookies(cookies, capRes.cookies);
  const captchaPng = Buffer.isBuffer(capRes.body) ? capRes.body : Buffer.from(capRes.body);
  const id = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  const session = { id, cookies, csrf, captchaPng, html: pageRes.body, time: Date.now() };
  _ecSessions.set(id, session);
  return session;
}

async function loadEcZonesFromPage() {
  try {
    const pageCtx = await getEcPage();
    const zones = parseJsonOrSelectOptions(pageCtx.html, 'cmb_Zone');
    if (zones.length > 0) return zones;
  } catch (_) {}
  return [];
}

async function loadEcDistrictsForZone(zoneCode) {
  try {
    const pageCtx = await getEcPage();
    const ctx = await ecAjax(pageCtx, 'loadDistrictCombo', zoneCode);
    const districts = parseJsonOrSelectOptions(ctx.html, 'cmb_District');
    if (districts.length > 0) return districts;
  } catch (_) {}
  return STATIC_EC_DISTRICTS[zoneCode] || [];
}

function pickEcVillage(villages, hint) {
  if (!villages?.length) return null;
  if (!hint) return villages[0];
  const q = String(hint).toLowerCase();
  for (const v of villages) {
    const n = v.name.toLowerCase();
    if (n === q || n.includes(q) || q.includes(n)) return v;
  }
  const tokens = q.split(/[\s\-,/]+/).filter((t) => t.length > 2);
  for (const v of villages) {
    const n = v.name.toLowerCase();
    if (tokens.some((t) => n.includes(t))) return v;
  }
  return villages[0];
}

async function checkEcPortalCaptcha(ctx, captcha) {
  const url = `${EC_BASE}/portal/webHP?requestType=ApplicationRH&actionVal=checkCaptcha&queryType=Select&screenId=114&captcha_val=${encodeURIComponent(captcha)}`;
  const res = await fetchRaw(url, {
    method:  'POST',
    body:    `_csrf=${encodeURIComponent(ctx.csrf)}`,
    cookies: ctx.cookies,
    headers: {
      Referer:            EC_URL,
      'Content-Type':     'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
    },
  });
  if (res.status !== 200) return false;
  const parts = String(res.body || '').split('#');
  const flag  = (parts[2] || '').trim().toLowerCase();
  if (flag === 'true') return true;
  if (flag === 'false') return false;
  return !/false|invalid|தவறு/i.test(String(res.body || ''));
}

function extractEcHiddenFields(html) {
  const pick = (name) => {
    const m = html.match(new RegExp(`(?:id|name)=["']${name}["'][^>]*value=["']([^"']*)["']`, 'i'))
           || html.match(new RegExp(`(?:id|name)=["']${name}["'][^>]*value=\\s*["']\\s*([^"']+)`, 'i'));
    return m ? m[1].trim() : '';
  };
  return {
    jsonString:         pick('jsonString'),
    templateIds:        pick('templateIds'),
    appTransId:         pick('appTransId') || '0',
    previewFlagFrmCnfg: pick('previewFlagFrmCnfg') || 'true',
    countNoRecords:     pick('countNoRecords'),
  };
}

function extractEcJsonStringFromHtml(html) {
  const hidden = extractEcHiddenFields(html);
  if (hidden.jsonString && hidden.jsonString.length > 4) return hidden.jsonString;

  const ids = [];
  const chkPat = /name=["'][^"']*chk[^"']*["'][^>]*value=["']([^"']+)["'][^>]*checked/gi;
  let m;
  while ((m = chkPat.exec(html)) !== null) ids.push(m[1]);

  if (ids.length === 0) {
    const valPat = /name=["'][^"']*chk[^"']*["'][^>]*value=["']([^"']+)["']/gi;
    while ((m = valPat.exec(html)) !== null) ids.push(m[1]);
  }
  if (ids.length > 0) return ids.join('#');
  return '';
}

function extractEcDisplayHtml(rawHtml) {
  if (!rawHtml || rawHtml.length < 200) return null;
  const prop = rawHtml.match(/<div[^>]*id=["']divPropertyList["'][^>]*>([\s\S]*?)<\/div>/i);
  if (prop && prop[1].trim().length > 80) {
    return wrapPattaPrintHtml('Encumbrance Certificate (EC)', 'tnreginet.gov.in', prop[1]);
  }
  const tables = [];
  const tablePat = /<table[^>]*class=["'][^"']*its[^"']*["'][^>]*>[\s\S]*?<\/table>/gi;
  let t;
  while ((t = tablePat.exec(rawHtml)) !== null) {
    if (!/captcha|menu|logout/i.test(t[0]) && t[0].length > 120) tables.push(t[0]);
  }
  if (tables.length > 0) {
    return wrapPattaPrintHtml(
      'Encumbrance Certificate (EC)',
      'tnreginet.gov.in',
      tables.join('<hr/>'),
    );
  }
  return null;
}

async function fetchEcPreviewPdf(ctx, { jsonString, templateIds, appTransId, fromDate, toDate }) {
  if (!jsonString || jsonString.length < 4) return null;
  const tableString = '8400001~A4~NA~1~1~2.5~2.5~29.7~21.0~LandScape~cm~null~2.5';
  const encJson = encodeURIComponent(String(jsonString).replace(/#/g, '$%$'));
  const url =
    `${EC_BASE}/portal/webHP?requestType=ApplicationRH&actionVal=previewECWisePdf&screenId=8400001` +
    `&appTransId=${encodeURIComponent(appTransId || '0')}` +
    `&docCreateAppId=8400001&tmpltMstID=8400003&previewFlagFrmCnfg=true` +
    `&templateIds=${encodeURIComponent(templateIds || '')}` +
    `&tableString=${encodeURIComponent(tableString)}` +
    `&txt_PeriodStartDt=${encodeURIComponent(fromDate)}` +
    `&txt_PeriodEndDt=${encodeURIComponent(toDate)}` +
    `&jsonString=${encJson}`;

  const res = await fetchRaw(url, {
    cookies: ctx.cookies,
    headers: { Referer: EC_URL, Accept: 'application/pdf,*/*' },
  });
  if (res.status !== 200) return null;
  const buf = Buffer.isBuffer(res.body) ? res.body : Buffer.from(String(res.body), 'binary');
  if (buf.length > 100 && buf.slice(0, 5).toString() === '%PDF-') return buf;
  return null;
}

async function ecGetVillageDetails(ctx, { villageCode, sro, surveyNo, subDiv, fromDate, toDate, isRevenueVillage = false }) {
  const surveyParam = isRevenueVillage ? (surveyNo || '') : '0';
  const subDivParam = isRevenueVillage ? (subDiv || '') : '0';
  const url = `${EC_BASE}/portal/webHP?requestType=ApplicationRH&actionVal=getVillageDetails&screenId=8400001&villageList=${encodeURIComponent(villageCode)}&sroId=${encodeURIComponent(sro)}&usrStartDt=${encodeURIComponent(fromDate)}&usrEndDt=${encodeURIComponent(toDate)}&isRevenueVillage=${isRevenueVillage}&surveyNumber=${encodeURIComponent(surveyParam)}&subDivisionNumber=${encodeURIComponent(subDivParam)}&_csrf=${encodeURIComponent(ctx.csrf)}`;
  const res = await fetchRaw(url, {
    method:  'POST',
    cookies: ctx.cookies,
    headers: { Referer: EC_URL, 'X-Requested-With': 'XMLHttpRequest' },
  });
  return { body: res.body, cookies: mergeCookies(ctx.cookies, res.cookies) };
}

function ecVillageDetailsOk(html) {
  if (ecPortalIsErrorPage(html)) return false;
  if (!html || html.length < 2) return false;
  const parts = String(html).split('<#>');
  const count = (parts[1] || '').trim();
  if (count.length > 0) {
    return html.includes('கிராமத்திற்கான தரவு கிடைக்கும் காலம்');
  }
  return true;
}

function ecSearchLooksLikeForm(html) {
  return html.includes('btn_SearchDoc') && html.includes('captchaDivId');
}

function ecPortalIsErrorPage(html) {
  if (!html || typeof html !== 'string' || html.length < 200) return false;
  if (/<title>\s*Error Page\s*<\/title>/i.test(html)) return true;
  if (/உங்கள் அமர்வு காலாவதியாகி/.test(html)) return true;
  if (/மன்னிக்கவும்!?\s*தவறு ஏற்பட்டுள்ளது/.test(html)) return true;
  return false;
}

function ecPortalErrorMessage(html) {
  if (/உங்கள் அமர்வு காலாவதியாகி/.test(html)) {
    return 'EC session expired. Refresh the captcha and try again.';
  }
  if (/சரியான காப்புக் குறியீட்டினை|incCaptcha|தயவுசெய்து குறியீட்டு/i.test(html)) {
    return 'Incorrect captcha. Refresh the image, enter the new code, and try again.';
  }
  if (ecPortalIsErrorPage(html)) {
    return 'TN registration portal rejected the request. Refresh captcha and try again.';
  }
  return null;
}

function ecSearchHasNoRecords(html) {
  const hidden = extractEcHiddenFields(html);
  if (hidden.countNoRecords === '0') return true;
  return /தேடுதல் காலத்தில் எந்த ஆவணங்களும் பதிவு செய்யப்படவில்லை/.test(html)
      || /divNothingFound[^>]*style="[^"]*display:\s*block/i.test(html);
}

function matchEcSro(sros, talukOrArea) {
  if (!talukOrArea || !sros?.length) return null;
  const q = String(talukOrArea).toLowerCase();
  for (const s of sros) {
    const n = s.name.toLowerCase();
    if (n === q || n.includes(q) || q.includes(n)) return s;
  }
  const tokens = q.split(/[\s\-,/]+/).filter((t) => t.length > 3);
  for (const s of sros) {
    const n = s.name.toLowerCase();
    if (tokens.some((t) => n.includes(t))) return s;
  }
  return null;
}

async function loadEcSrosForDistrict(zoneCode, districtCode) {
  try {
    const pageCtx   = await getEcPage();
    const afterZone = await ecAjax(pageCtx, 'loadDistrictCombo', zoneCode);
    const afterDist = await ecAjax(afterZone, 'loadSroCombo', districtCode);
    const sros = parseJsonOrSelectOptions(afterDist.html, 'cmb_SroName');
    if (sros.length > 0) return sros;
  } catch (_) {}
  return STATIC_EC_SROS[districtCode] || [];
}

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

  const newCsrf = (res.body.match(/var\s+csrf\s*=\s*'([^']+)'/i) ||
                   res.body.match(/name="_csrf" content="([^"]+)"/i) || [])[1];
  return {
    html: res.body,
    cookies: mergeCookies(pageCtx.cookies, res.cookies),
    csrf: newCsrf || pageCtx.csrf,
  };
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

function formatEcDate(d) {
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}/${month}/${year}`;
}

function buildEcPeriodPresets() {
  const now = new Date();
  const presets = [];
  for (let y = now.getFullYear(); y >= now.getFullYear() - 9; y--) {
    presets.push({
      id:       String(y),
      label:    `${y} (01/01/${y} – 31/12/${y})`,
      fromDate: `01/01/${y}`,
      toDate:   `31/12/${y}`,
    });
  }
  presets.push({
    id:       'full',
    label:    `Full period (01/01/2000 – ${formatEcDate(now)})`,
    fromDate: '01/01/2000',
    toDate:   formatEcDate(now),
  });
  return presets;
}

function ecRecordLabel(record, index) {
  const dateKey = Object.keys(record).find((k) => /date/i.test(k));
  const dateVal = dateKey ? record[dateKey] : '';
  const docKey = Object.keys(record).find((k) => /doc|deed|number|no/i.test(k) && !/date/i.test(k));
  const docVal = docKey ? record[docKey] : '';
  const typeVal = record['Nature of Document'] || record['Document Type'] || record['Type'] || '';
  const parts = [dateVal, typeVal, docVal].filter(Boolean);
  return parts.length > 0 ? parts.join(' · ') : `Entry ${index + 1}`;
}

function ecEntriesFromRecords(records = []) {
  return records.map((record, index) => ({
    id:    String(index),
    label: ecRecordLabel(record, index),
    date:  Object.entries(record).find(([k]) => /date/i.test(k))?.[1] || '',
  }));
}

function buildEcDocumentHtml(records, meta = {}) {
  if (!records || records.length === 0) {
    return wrapPattaPrintHtml(
      'Encumbrance Certificate (EC)',
      'tnreginet.gov.in',
      '<p>No encumbrance records found for the selected period.</p>',
    );
  }

  const metaRows = Object.entries(meta)
    .filter(([, v]) => v != null && String(v).trim() !== '')
    .map(([k, v]) => `<tr><th>${escHtml(k)}</th><td>${escHtml(v)}</td></tr>`)
    .join('');

  const headers = Object.keys(records[0]);
  const headerRow = headers.map((h) => `<th>${escHtml(h)}</th>`).join('');
  const bodyRows = records.map((r) =>
    `<tr>${headers.map((h) => `<td>${escHtml(r[h] || '')}</td>`).join('')}</tr>`,
  ).join('');

  const body = `
    <table>${metaRows}</table>
    <p class="sub">${records.length} registration record(s) in this period.</p>
    <div style="overflow-x:auto">
      <table>
        <thead><tr>${headerRow}</tr></thead>
        <tbody>${bodyRows}</tbody>
      </table>
    </div>`;

  return wrapPattaPrintHtml('Encumbrance Certificate (EC)', 'tnreginet.gov.in', body);
}

async function searchEcPortal(query) {
  const {
    zone, dc, sro, surveyNo, subDiv, fromDate, toDate, village, villageName, captcha, ecSession,
  } = query;

  if (!captcha || !ecSession) {
    const err = new Error('Captcha required. Load captcha and enter the code shown on the image.');
    err.captchaRequired = true;
    throw err;
  }

  const sess = getEcSession(ecSession);
  if (!sess) {
    const err = new Error('EC session expired. Refresh the captcha and try again.');
    err.captchaRequired = true;
    throw err;
  }

  let ctx = { cookies: sess.cookies, csrf: sess.csrf, html: sess.html };

  ctx = await ecAjax(ctx, 'loadDistrictCombo', zone);
  ctx = await ecAjax(ctx, 'loadSroCombo', dc);
  ctx = await ecAjax(ctx, 'loadVillageCombo', sro);
  touchEcSession(ecSession, ctx);

  const villages = parseJsonOrSelectOptions(ctx.html, 'cmb_Village');
  const vill = village
    ? villages.find((v) => v.code === village) || { code: village, name: villageName || village }
    : pickEcVillage(villages, villageName);
  if (!vill?.code) {
    throw new Error('Could not load registration village for this SRO. Try another SRO manually.');
  }

  const villRes = await ecGetVillageDetails(ctx, {
    villageCode: vill.code,
    sro,
    surveyNo,
    subDiv,
    fromDate,
    toDate,
    isRevenueVillage: false,
  });
  ctx.cookies = mergeCookies(ctx.cookies, villRes.cookies);
  touchEcSession(ecSession, ctx);

  if (!ecVillageDetailsOk(villRes.body)) {
    console.warn('[EC] getVillageDetails failed:', String(villRes.body).slice(0, 400));
    const msg = ecPortalErrorMessage(villRes.body);
    const err = new Error(msg || 'Could not validate village for this SRO. Try another SRO.');
    err.captchaRequired = /captcha|குறியீட்டு/i.test(String(msg || ''));
    throw err;
  }

  const formParams = encodeForm({
    requestType:              'ApplicationRH',
    actionVal:                'searchDocYearWise',
    screenId:                 '8400001',
    divId:                    'searchComponentSection',
    isPlotFlatWise:           'false',
    isRevenueVillage:         'false',
    formId:                   'EncumbranceCertificateForm',
    validVillage:             '1',
    loggedInGuest:            'false',
    isECValid:                'N',
    multiVillageLimitEC:      '3',
    [EC_CTRL.zone]:           zone,
    [EC_CTRL.district]:       dc,
    [EC_CTRL.sro]:            sro,
    [EC_CTRL.village]:        vill.code,
    [EC_CTRL.surveyNo]:       surveyNo,
    [EC_CTRL.subDiv]:         subDiv || '',
    [EC_CTRL.fromDate]:       fromDate,
    [EC_CTRL.toDate]:         toDate,
    [EC_CTRL.captcha]:        captcha,
    [EC_CTRL.captchaVal]:     encodeURIComponent(captcha),
    txt_convExtent:           '1',
    multi_SurveyNo:           surveyNo,
    multi_SubDivisionNo:      subDiv || '',
    multi_cmb_Village:        vill.code,
    hdnCmnDDMMYYlert:         '',
    hdnCmnDateAlert:          '',
    hdn_year:                 '',
    SpecialCharAndSpaceAlert: '',
  });

  const searchUrl =
    `${EC_BASE}/portal/webHP?requestType=ApplicationRH&actionVal=searchDocYearWise&screenId=8400001` +
    `&divId=searchComponentSection&isPlotFlatWise=false&isRevenueVillage=false` +
    `&villageList=${encodeURIComponent(vill.code)}` +
    `&surveyNumber=${encodeURIComponent(surveyNo)}` +
    `&subDivisionNumber=${encodeURIComponent(subDiv || '')}` +
    `&usrStartDt=${encodeURIComponent(fromDate)}` +
    `&usrEndDt=${encodeURIComponent(toDate)}` +
    `&_csrf=${encodeURIComponent(ctx.csrf)}&${formParams}`;

  const result = await fetchRaw(searchUrl, {
    cookies: ctx.cookies,
    headers: {
      Referer: EC_URL,
      'X-Requested-With': 'XMLHttpRequest',
    },
  });
  ctx.cookies = mergeCookies(ctx.cookies, result.cookies);
  touchEcSession(ecSession, ctx);

  if (result.status !== 200) {
    throw new Error(`EC portal returned HTTP ${result.status}`);
  }

  if (ecPortalIsErrorPage(result.body)) {
    console.warn('[EC] search error page:', String(result.body).slice(0, 400));
    const msg = ecPortalErrorMessage(result.body);
    const err = new Error(msg || 'EC portal error. Refresh captcha and try again.');
    err.captchaRequired = true;
    throw err;
  }

  if (ecSearchHasNoRecords(result.body)) {
    return { records: [], rawHtml: result.body, noRecords: true, village: vill };
  }

  if (/சரியான காப்புக் குறியீட்டினை|incCaptcha|தயவுசெய்து குறியீட்டு/i.test(result.body)
      && ecSearchLooksLikeForm(result.body)) {
    const err = new Error('Incorrect captcha. Refresh the image, enter the new code, and try again.');
    err.captchaRequired = true;
    throw err;
  }

  if (ecSearchLooksLikeForm(result.body)) {
    const err = new Error('EC search was rejected by tnreginet. Check captcha, SRO, and survey number.');
    err.captchaRequired = /incCaptcha|குறியீட்டு/i.test(result.body);
    throw err;
  }

  const records = parseEcResults(result.body);
  const hidden  = extractEcHiddenFields(result.body);
  const jsonStr = extractEcJsonStringFromHtml(result.body) || hidden.jsonString;
  const portalHtml = extractEcDisplayHtml(result.body);

  if (records.length === 0 && !jsonStr && !portalHtml) {
    if (ecSearchHasNoRecords(result.body)) {
      return { records: [], rawHtml: result.body, noRecords: true, village: vill };
    }
    const err = new Error('Could not read EC results from tnreginet. Refresh captcha and try again.');
    err.captchaRequired = true;
    throw err;
  }

  let pdfBuf = null;
  if (jsonStr) {
    pdfBuf = await fetchEcPreviewPdf(ctx, {
      jsonString: jsonStr,
      templateIds: hidden.templateIds,
      appTransId:  hidden.appTransId,
      fromDate,
      toDate,
    });
  }
  return {
    records,
    rawHtml: result.body,
    village: vill,
    pdfBuf,
    portalHtml,
    jsonString: jsonStr,
  };
}

// ── EC Routes ─────────────────────────────────────────────────────────────────

router.get('/ec/zones', async (req, res) => {
  try {
    const zones = await loadEcZonesFromPage();
    if (zones.length > 0) return res.json(zones);
  } catch (_) {}
  res.json(EC_ZONES_LEGACY);
});

router.get('/ec/captcha', async (req, res) => {
  try {
    const session = await createEcSession();
    res.json({
      sessionId:    session.id,
      captchaImage: `data:image/png;base64,${session.captchaPng.toString('base64')}`,
      expiresIn:    EC_SESSION_TTL_MS / 1000,
      source:       'tnreginet.gov.in',
    });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/ec/periods', (req, res) => {
  res.json(buildEcPeriodPresets());
});

router.get('/ec/resolve', async (req, res) => {
  const { lat, lon, district, taluk, village } = req.query;
  const latN = parseFloat(lat);
  const lonN = parseFloat(lon);

  const coordHint = coordDistrictHint(latN, lonN);
  let districtName = district;
  if (!districtName && coordHint) districtName = coordHint.label;

  if (!districtName && !coordHint) {
    return res.status(400).json({
      error: 'Could not resolve district from map location.',
      hint:  'Tap the map on your parcel or fetch patta first.',
    });
  }

  try {
    const liveZones = await loadEcZonesFromPage();
    const zonesToTry = [];
    const seen = new Set();
    const pushZone = (z) => {
      if (!z || seen.has(z.code)) return;
      seen.add(z.code);
      zonesToTry.push(z);
    };
    if (coordHint) {
      pushZone(liveZones.find((z) => z.code === coordHint.zone));
    }
    for (const z of liveZones) pushZone(z);
    for (const z of EC_ZONES_LEGACY) pushZone(z);

    for (const zone of zonesToTry) {
      const districts = await loadEcDistrictsForZone(zone.code);
      if (!districts.length) continue;

      let dist = null;
      if (coordHint && coordHint.zone === zone.code && coordHint.dc) {
        dist = districts.find((d) => d.code === coordHint.dc);
      }
      if (!dist && districtName) {
        dist = matchEcDistrict(districts, districtName);
      }
      if (!dist && coordHint && coordHint.zone === zone.code) {
        dist = districts[0];
      }
      if (!dist) continue;

      const sros = await loadEcSrosForDistrict(zone.code, dist.code);
      const areaHint = [taluk, village, districtName].filter(Boolean).join(' ');
      const suggestedSro = matchEcSro(sros, areaHint) || sros[0] || null;

      return res.json({
        source:       'tnreginet.gov.in',
        zone:         { code: zone.code, name: zone.name },
        district:     dist,
        sros,
        suggestedSro,
        resolvedFrom: coordHint ? 'coordinates' : 'district-name',
      });
    }

    return res.status(404).json({
      error: `District "${districtName || 'unknown'}" not found in EC registry.`,
      hint:  'Use Manual — Zone / District / SRO below.',
    });
  } catch (err) {
    return res.status(502).json({ error: err.message });
  }
});

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
  const { zone, dc, sro, surveyNo, subDiv, fromDate, toDate, captcha, ecSession, villageName } = req.query;
  if (!zone || !dc || !sro || !surveyNo || !fromDate || !toDate) {
    return res.status(400).json({
      error: 'zone, dc, sro, surveyNo, fromDate, toDate required (dates: DD/MM/YYYY)',
    });
  }
  if (!captcha || !ecSession) {
    return res.status(400).json({
      error:       'Captcha required for EC search.',
      hint:        'Load the captcha image, enter the code, then fetch EC.',
      captchaRequired: true,
    });
  }

  try {
    let searchResult = await searchEcPortal(req.query);
    let usedSro = req.query.sro;
    let usedSroName = req.query.sroName || sro;

    const hasEcData = (r) =>
      (r.records?.length > 0) ||
      (r.pdfBuf?.length > 0) ||
      (r.portalHtml && r.portalHtml.length > 200);

    if (!hasEcData(searchResult) && searchResult.noRecords) {
      try {
        const sros = await loadEcSrosForDistrict(zone, dc);
        const startIdx = sros.findIndex((s) => s.code === sro);
        for (let i = 0; i < sros.length && i < 8; i++) {
          if (i === startIdx) continue;
          const alt = sros[i];
          try {
            const altResult = await searchEcPortal({
              ...req.query,
              sro: alt.code,
              sroName: alt.name,
            });
            if (hasEcData(altResult)) {
              searchResult = altResult;
              usedSro = alt.code;
              usedSroName = alt.name;
              break;
            }
            if (altResult.noRecords) searchResult = altResult;
          } catch (altErr) {
            if (altErr.captchaRequired) throw altErr;
          }
        }
      } catch (_) {}
    }

    const { records, noRecords, village, pdfBuf, portalHtml } = searchResult;

    const zoneName = (await loadEcZonesFromPage()).find((z) => z.code === zone)?.name || zone;
    const meta = {
      Zone:           zoneName,
      District:       req.query.districtName || dc,
      SRO:            usedSroName || usedSro,
      Village:        village?.name || villageName || '-',
      'Survey No':    surveyNo,
      'Sub Division': subDiv || '-',
      Period:         `${fromDate} to ${toDate}`,
    };

    const html = portalHtml || buildEcDocumentHtml(records, meta);
    const fileStem = `EC-${surveyNo}-${fromDate.replace(/\//g, '-')}`;
    const document = {
      type:      'ec',
      source:    'tnreginet.gov.in',
      available: true,
      html,
      fileName:  `${fileStem}.html`,
    };
    if (pdfBuf && pdfBuf.length > 0) {
      document.pdfBase64 = pdfBuf.toString('base64');
      document.pdfFileName = `${fileStem}.pdf`;
      document.mimeType = 'application/pdf';
    }

    const hasDocument = (pdfBuf && pdfBuf.length > 0) || (portalHtml && portalHtml.length > 200);

    if ((noRecords || records.length === 0) && !hasDocument) {
      return res.json({
        source:   'tnreginet.gov.in',
        count:    0,
        records:  [],
        entries:  [],
        document,
        meta,
        message: 'No encumbrance records found for this survey/period.',
        hint:    'Try another SRO from the list or verify the survey number.',
      });
    }

    res.json({
      source:   'tnreginet.gov.in',
      count:    records.length,
      records,
      entries:  ecEntriesFromRecords(records),
      document,
      meta,
    });
  } catch (err) {
    const status = err.captchaRequired ? 400 : 502;
    res.status(status).json({
      error: err.message,
      captchaRequired: Boolean(err.captchaRequired),
      hint: err.captchaRequired
        ? 'Tap refresh captcha, enter the code, and try again.'
        : 'Verify SRO and survey number; try manual SRO selection.',
    });
  }
});

module.exports = router;
