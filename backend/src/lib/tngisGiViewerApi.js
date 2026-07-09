const https = require('https');
const zlib = require('zlib');

let getCachedLandDetails = async () => null;
let putCachedLandDetails = async () => {};
try {
  ({ getCachedLandDetails, putCachedLandDetails } = require('./tngisCache'));
} catch (_) {
  // tngisCache is optional in dev; production should ship backend/src/lib/tngisCache.js.
}

const GI_VIEWER_API = 'https://tngis.tn.gov.in/apps/gi_viewer_api/api';
const IGR_URL = 'https://tngis.tn.gov.in/apps/thematic_viewer_api/v1/getfeatureInfo';
const TAMIL_NILAM_API = 'https://tngis.tn.gov.in/apps/tamilnilam_api/v1';
const FMB_SKETCH_URL = 'https://tngis.tn.gov.in/apps/generic_api/v1/sketch_fmb';
const GI_REFERER = 'https://tngis.tn.gov.in/apps/gi_viewer/map-viewer/index.html';

// Upstream TNGIS POSTs (land_details, AREG, pattacopy, FMB) must fail fast — a
// hung request would otherwise block until Vercel kills the function at 120s
// (FUNCTION_INVOCATION_TIMEOUT), so callers get a 504 instead of a JSON error.
const TNGIS_POST_TIMEOUT_MS = 18000;

function padTalukCode(code) {
  const s = String(code ?? '').trim();
  if (!s) return '';
  return s.length >= 2 ? s : s.padStart(2, '0');
}

// Scan a chunk of decoded PDF text for the known TNGIS/CollabLand error strings.
function textHasFmbError(text) {
  const t = text.toLowerCase();
  if (t.includes('does not exist in this fmb')) return true;
  if (t.includes('does not exist') && t.includes('survey number')) return true;
  if (t.includes('requested survey number') && t.includes('does not exist')) return true;
  if (t.includes('not available') && t.includes('fmb')) return true;
  if (t.includes('no sketch') || t.includes('not digitized')) return true;
  return false;
}

/**
 * TNGIS sometimes returns a PDF "error page" (e.g. "The requested survey number
 * X does not exist in this FMB") instead of a real sketch. These are tricky:
 * the error text is drawn as vector glyph outlines, not selectable text, so a
 * plain string scan of the raw bytes can't see it. We therefore combine three
 * signals:
 *   1. raw-byte text scan   — catches PDFs whose error text is real text (Tj),
 *   2. inflated-stream scan  — catches FlateDecode-compressed text error pages,
 *   3. size heuristic        — the TNGIS error/blank template is a ~13KB page;
 *                              a genuine cadastral FMB sketch (survey outline,
 *                              subdivision lines, corner coords, title block) is
 *                              always far larger (100KB+). Small PDFs are errors.
 */
function isInvalidFmbPdfBase64(pdfBase64) {
  if (!pdfBase64 || String(pdfBase64).length < 100) return true;
  let buf;
  try {
    buf = Buffer.from(String(pdfBase64), 'base64');
  } catch (_) {
    return true;
  }

  // 1) raw-byte text scan
  const raw = buf.toString('latin1');
  if (textHasFmbError(raw)) return true;

  // 2) inflate every FlateDecode stream and scan the decoded content
  try {
    const re = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
    let m;
    while ((m = re.exec(raw)) !== null) {
      try {
        const out = zlib.inflateSync(Buffer.from(m[1], 'latin1')).toString('latin1');
        if (textHasFmbError(out)) return true;
      } catch (_) { /* not a zlib stream — skip */ }
    }
  } catch (_) { /* fall through to size check */ }

  // 3) Size heuristic. The TNGIS "does not exist / blank" error template is a
  // ~13KB page whose error text is drawn as vector glyph outlines, so the text
  // scans above can't see it. A genuine cadastral FMB sketch (survey outline,
  // subdivision lines, corner coordinates, Tahsildar seal + title block) is
  // always far larger — the smallest real sketches we see are 100KB+. Anything
  // under ~30KB is the error/blank template, never a real government sketch.
  if (buf.length < 30 * 1024) return true;

  return false;
}

function postJson(url, payload, headers = {}) {
  const body = JSON.stringify(payload);
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request({
      hostname: u.hostname,
      path: u.pathname,
      method: 'POST',
      headers: {
        Referer: GI_REFERER,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json; charset=UTF-8',
        'Content-Length': Buffer.byteLength(body),
        ...headers,
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: JSON.parse(data), raw: data });
        } catch (_) {
          resolve({ status: res.statusCode, json: null, raw: data });
        }
      });
    });
    req.setTimeout(TNGIS_POST_TIMEOUT_MS, () => { req.destroy(new Error('TNGIS request timed out')); });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function postForm(url, fields, headers = {}) {
  const body = new URLSearchParams(
    Object.fromEntries(Object.entries(fields).filter(([, v]) => v != null)),
  ).toString();

  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request({
      hostname: u.hostname,
      path: u.pathname,
      method: 'POST',
      headers: {
        Referer: GI_REFERER,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Content-Length': Buffer.byteLength(body),
        ...headers,
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: JSON.parse(data), raw: data });
        } catch (_) {
          resolve({ status: res.statusCode, json: null, raw: data });
        }
      });
    });
    req.setTimeout(TNGIS_POST_TIMEOUT_MS, () => { req.destroy(new Error('TNGIS request timed out')); });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function formatIndianRupees(amount) {
  const n = Number(String(amount ?? '').replace(/,/g, ''));
  if (!Number.isFinite(n)) return null;
  return `₹${new Intl.NumberFormat('en-IN').format(n)}`;
}

// ── land_details cache ────────────────────────────────────────────────
// rate_limit_land_details (X-APP-NAME: demo) is heavily throttled per IP —
// the official GI Viewer dodges it because each browser has its own quota,
// but our backend funnels every lookup through one server IP. Cache by
// rounded coordinate so repeat taps cost no quota, and keep serving the
// last-known result when the upstream returns "Too many requests".
const LAND_DETAILS_TTL = 24 * 60 * 60 * 1000; // serve fresh for 24h
const LAND_DETAILS_MAX = 1000;                // cap entries (LRU-ish)
const _landDetailsCache = new Map();          // key → { result, time }

function landDetailsKey(lat, lon) {
  // 5 decimals ≈ 1.1m — dedupes re-taps on the same pin without merging
  // neighbouring parcels.
  return `${Number(lat).toFixed(5)},${Number(lon).toFixed(5)}`;
}

function rememberLandDetails(key, result) {
  _landDetailsCache.delete(key); // re-insert so iteration order = recency
  _landDetailsCache.set(key, { result, time: Date.now() });
  if (_landDetailsCache.size > LAND_DETAILS_MAX) {
    _landDetailsCache.delete(_landDetailsCache.keys().next().value);
  }
}

// Land parcels don't move — the shared DB cache can serve resolved points for
// a long time (survey/sub only change on re-survey, which is rare).
const LAND_DETAILS_DB_TTL = 90 * 24 * 60 * 60 * 1000; // 90 days

async function fetchGiLandDetails(lat, lon) {
  const key = landDetailsKey(lat, lon);
  const cached = _landDetailsCache.get(key);
  if (cached && Date.now() - cached.time < LAND_DETAILS_TTL) {
    return { ...cached.result, cached: true };
  }

  // Shared persistent cache — another user/instance may have already resolved
  // this exact point, so we can skip the throttled upstream entirely.
  let dbRow = null;
  try { dbRow = await getCachedLandDetails(key); } catch (_) {}
  if (dbRow?.data && dbRow.updatedAt
      && Date.now() - new Date(dbRow.updatedAt).getTime() < LAND_DETAILS_DB_TTL) {
    const result = { ...dbRow.data, ok: true };
    rememberLandDetails(key, result);
    return { ...result, cached: true };
  }

  const { status, json } = await postForm(
    `${GI_VIEWER_API}/rate_limit_land_details`,
    { latitude: lat, longitude: lon, up: '', uid: '' },
    { 'X-APP-NAME': 'demo' },
  );

  if (json && json.success === 1 && json.data) {
    const d = json.data;
    const pickFirst = (...vals) => {
      for (const v of vals) {
        if (v === null || v === undefined) continue;
        const s = String(v).trim();
        if (!s || s === '-') continue;
        return s;
      }
      return null;
    };
    const result = {
      ok: true,
      source: 'TNGIS GI Viewer land_details',
      ulpin: d.ulpin || null,
      centroid: d.centroid || `${lat}, ${lon}`,
      // Urban responses can use TS/block keys instead of survey/sub_division.
      surveyNumber: pickFirst(
        d.survey_number,
        d.survey_no,
        d.ts_number,
        d.ts_no,
        d.tslr_survey_no,
        d.town_survey_no,
      ),
      subDivision: pickFirst(
        d.sub_division,
        d.sub_division_number,
        d.subdivision,
        d.block_number,
        d.block_no,
        d.ward_block_no,
      ),
      districtCode: pickFirst(d.district_code, d.districtCode),
      talukCode: pickFirst(d.taluk_code, d.talukCode),
      villageCode: pickFirst(d.village_code, d.villageCode),
      ruralUrban: pickFirst(d.rural_urban, d.ruralUrban, d.land_type),
      isFmb: d.is_fmb,
      raw: d,
    };
    rememberLandDetails(key, result);
    // Persist for everyone (drop the bulky raw payload). Fire-and-forget.
    const { raw, ...toStore } = result;
    putCachedLandDetails(key, toStore).catch(() => {});
    return result;
  }

  // Upstream failed or rate-limited — fall back to any last-known good result,
  // preferring the in-memory copy then the shared DB copy (even if stale).
  if (cached) return { ...cached.result, cached: true, stale: true };
  if (dbRow?.data) {
    const result = { ...dbRow.data, ok: true };
    rememberLandDetails(key, result);
    return { ...result, cached: true, stale: true };
  }

  if (!json) return { ok: false, error: `HTTP ${status}` };
  const msg = json.message || json.error || 'Land details unavailable';
  return { ok: false, error: msg, rateLimited: /too many requests/i.test(String(msg)) };
}

async function fetchGiGuidelineValue(lat, lon) {
  const { status, json } = await postForm(
    IGR_URL,
    { latitude: lat, longitude: lon, layer_name: 'Thematic_XYZ' },
    { 'X-APP-ID': 'te$t' },
  );
  if (!json) return { ok: false, error: `HTTP ${status}` };
  if (json.success !== 1 || !Array.isArray(json.data) || json.data.length === 0) {
    return { ok: false, error: json.message || 'Guideline Value not found for the selected Land' };
  }
  const items = json.data.map((item) => ({
    landType: item.land_name || null,
    classification: item.land_name_type || null,
    metricRate: formatIndianRupees(item.metric_rate),
    metricRateRaw: item.metric_rate ?? null,
    pricePerHectare: formatIndianRupees(item.price_per_hect),
    pricePerHectareRaw: item.price_per_hect ?? null,
    unitId: item.unit_id || null,
    surveyNumber: item.survey_number || null,
    subDivision: item.sub_division || null,
    village: item.vname || null,
    district: item.dname || null,
    taluk: item.tname || null,
  }));
  return {
    ok: true,
    source: 'Registration Department (TNGIS IGR)',
    title: 'Guide Line Value from Registration Department',
    items,
  };
}

async function fetchGiCropSeason(lat, lon, season) {
  const { status, json } = await postForm(
    `${GI_VIEWER_API}/crop_details1`,
    { latitude: lat, longitude: lon, type: season },
    { 'X-APP-NAME': 'demo' },
  );
  if (!json) return { ok: false, season, error: `HTTP ${status}` };
  if (json.success !== 1 || !json.data) {
    return {
      ok: false,
      season,
      error: json.message || `No crop data for ${season}`,
    };
  }
  const d = json.data;
  const govtPri = d.govt_pri;
  return {
    ok: true,
    season,
    label: season.toUpperCase(),
    cropName: d.crop_name || null,
    classification: d.crop_classification_type || null,
    cropArea: d.crop_area ?? null,
    landArea: d.land_area ?? null,
    cropCount: d.crop_count ?? null,
    govtPriority: govtPri == null || govtPri === '' ? '—' : String(govtPri),
    dataSource: d.data_source || null,
    ruralUrban: d.rural_urban || null,
  };
}

async function fetchGiCropDetails(lat, lon) {
  const [rabi, kharif] = await Promise.all([
    fetchGiCropSeason(lat, lon, 'rabi'),
    fetchGiCropSeason(lat, lon, 'kharif'),
  ]);
  return {
    ok: rabi.ok || kharif.ok,
    source: 'TNGIS Crop Survey',
    title: 'Crop Information',
    seasons: { rabi, kharif },
  };
}

/** Tamil Nilam ownership (AREG) — same as GI Viewer Patta tab. */
async function fetchGiAregOwnership({
  districtCode, talukCode, villageCode, surveyNumber, subDivision,
  landType = 'rural',
}) {
  const { status, json } = await postForm(
    `${TAMIL_NILAM_API}/tamil_nillam_ownership`,
    {
      district_code: districtCode,
      taluk_code: padTalukCode(talukCode),
      village_code: padVillageCode(villageCode),
      survey_number: surveyNumber,
      sub_division_number: subDivision || '',
      land_type: landType,
      code_type: 'revenue',
      search_type: 'survey_number',
    },
    { 'X-APP-NAME': 'demo' },
  );
  if (!json) return { ok: false, error: `HTTP ${status}` };
  if (json.success !== 1 || !json.data) {
    return { ok: false, error: json.message || 'Tamil Nilam ownership not found' };
  }
  return {
    ok: true,
    source: 'TNGIS Tamil Nilam (tamil_nillam_ownership)',
    landDetail: json.data.land_detail || null,
    ownershipDetails: json.data.ownership_detail || null,
  };
}

/** Official Patta PDF from NIC via TNGIS pattacopy. */
async function fetchGiPattaCopy({
  districtCode, talukCode, villageCode, pattaNumber,
}) {
  const { status, json, raw } = await postForm(
    `${TAMIL_NILAM_API}/pattacopy`,
    {
      district_code: districtCode,
      taluk_code: padTalukCode(talukCode),
      village_code: padVillageCode(villageCode),
      patta_number: pattaNumber,
    },
    { 'X-APP-USER-ID': '12' },
  );
  let parsed = json;
  if (!parsed && raw) {
    try { parsed = JSON.parse(raw); } catch (_) {}
  }
  if (!parsed) return { ok: false, error: `HTTP ${status}` };
  if (parsed.success === '1' || parsed.success === 1) {
    const pdfBase64 = parsed.data;
    if (pdfBase64 && String(pdfBase64).length > 100) {
      return {
        ok: true,
        source: 'TNGIS Tamil Nilam (pattacopy)',
        pdfBase64: String(pdfBase64),
        fileName: `Patta-${pattaNumber}.pdf`,
      };
    }
  }
  return { ok: false, error: parsed.message || 'Patta copy not available from Tamil Nilam' };
}

function padVillageCode(code) {
  const s = String(code ?? '').trim();
  if (!s) return '';
  return s.padStart(3, '0');
}

/** FMB sketch PDF with government seal — TNGIS generic_api/sketch_fmb. */
async function fetchGiFmbSketch({
  districtCode, talukCode, villageCode, surveyNumber, subDivision,
  landType = 'rural', isFmb = true,
}) {
  const params = {
    districtCode: String(districtCode ?? '').trim(),
    talukCode: padTalukCode(talukCode),
    villageCode: padVillageCode(villageCode),
    surveyNumber: String(surveyNumber ?? '').trim(),
    subdivisionNumber: subDivision ? String(subDivision) : '',
    type: landType,
  };
  const { status, json } = await postForm(FMB_SKETCH_URL, params);
  if (!json) return { ok: false, error: `HTTP ${status}` };
  const ok = json?.success === 1 || json?.success === '1';
  const rawPdf = ok
    ? (json.data?.pdfBase64 ?? json.data?.pdf ?? json.data?.data ?? json.data)
    : null;
  if (ok && rawPdf) {
    const pdfBase64 = String(rawPdf);
    if (pdfBase64.length > 100 && !isInvalidFmbPdfBase64(pdfBase64)) {
      return {
        ok: true,
        source: 'TNGIS GI Viewer (sketch_fmb)',
        pdfBase64,
        fileName: `FMB-${surveyNumber}${subDivision ? `-Sub-${subDivision}` : ''}.pdf`,
        message: json.message || null,
      };
    }
    if (isInvalidFmbPdfBase64(pdfBase64)) {
      return { ok: false, error: 'FMB sketch not available for this survey/sub-division on TNGIS.' };
    }
  }
  return { ok: false, error: json.message || 'FMB sketch not available from TNGIS' };
}

/** Encumbrance Certificate PDF via TNGIS GI Viewer API. */
async function fetchGiEncumbranceCertificate({
  districtCode, talukCode, villageCode, surveyNumber, subDivision,
}) {
  const { status, json } = await postJson(
    `${GI_VIEWER_API}/encumbrance_certificate`,
    {
      revDistrictCode: String(districtCode ?? '').trim(),
      revTalukCode: padTalukCode(talukCode),
      revVillageCode: padVillageCode(villageCode),
      survey_number: String(surveyNumber ?? '').trim(),
      sub_division_number: subDivision ? String(subDivision) : 'jjjj',
    },
    { 'X-APP-NAME': 'demo' },
  );
  if (!json) return { ok: false, error: `HTTP ${status}` };
  if (json.status === 'success' && json.EC?.statusCode === 100) {
    const pdfBase64 = json.EC?.Base64String;
    if (pdfBase64 && String(pdfBase64).length > 100) {
      return {
        ok: true,
        source: 'TNGIS GI Viewer (encumbrance_certificate)',
        pdfBase64: String(pdfBase64),
        fileName: 'Encumbrance Certificate.pdf',
      };
    }
  }
  const msg = json.message || json.EC?.message
    || 'No Encumbrance Certificate data found for selected survey/subdivision';
  return { ok: false, error: msg };
}

function resolveSubFromTngisProps(props = {}, survey = '') {
  const surveyNo = String(survey || props.survey_number || '').trim();
  let sub = String(props.sub_division ?? props.subDivision ?? '').trim();
  if (sub && sub !== '-' && sub !== surveyNo) return sub;
  const kide = String(props.kide ?? '').trim();
  if (kide && kide !== '0' && kide.includes('/')) {
    const parts = kide.split('/');
    const kideSurvey = String(parts[0] ?? '').trim();
    const kideSub = parts.slice(1).join('/').trim();
    if (kideSub && kideSub !== '-' && kideSub !== surveyNo
        && (!surveyNo || !kideSurvey || kideSurvey === surveyNo)) {
      return kideSub;
    }
  }
  return '';
}

/** Resolve admin codes from GI land_details + WFS props. */
function mergeGiParcelCodes(giLand, tngisProps = {}, ctx = {}) {
  const surveyNumber = ctx.surveyNo || giLand?.surveyNumber || tngisProps.survey_number;
  const surveyStr = String(surveyNumber ?? '').trim();
  const ctxSub = String(ctx.subDiv || '').trim();
  const subDiffersFromSurvey = (s) => s && s !== '-' && s !== surveyStr;
  let sub = '';
  if (subDiffersFromSurvey(ctxSub)) {
    sub = ctxSub;
  } else {
    const giSub = String(giLand?.subDivision || '').trim();
    if (subDiffersFromSurvey(giSub)) {
      sub = giSub;
    } else {
      sub = resolveSubFromTngisProps(tngisProps, surveyStr);
    }
  }
  return {
    districtCode: giLand?.districtCode || tngisProps.district_code,
    talukCode: giLand?.talukCode || tngisProps.taluk_code,
    villageCode: giLand?.villageCode || tngisProps.village_code,
    surveyNumber,
    subDivision: sub,
    landType: giLand?.ruralUrban || 'rural',
    isFmb: giLand?.isFmb === 1 || giLand?.isFmb === '1'
      || tngisProps.is_fmb === 1 || tngisProps.is_fmb === '1',
  };
}

module.exports = {
  fetchGiLandDetails,
  fetchGiGuidelineValue,
  fetchGiCropSeason,
  fetchGiCropDetails,
  fetchGiAregOwnership,
  fetchGiPattaCopy,
  fetchGiFmbSketch,
  fetchGiEncumbranceCertificate,
  mergeGiParcelCodes,
  padTalukCode,
  padVillageCode,
  formatIndianRupees,
  isInvalidFmbPdfBase64,
};
