const express = require('express');
const https   = require('https');
const router  = express.Router();

const VALID_TYPES   = ['Building', 'Normal_Layout'];
const CURRENT_YEAR  = new Date().getFullYear();
const BROWSER_UA    =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

// ── Raw proxy (legacy) ─────────────────────────────────────────────────────────

router.get('/:year/:type', (req, res) => {
  const { year, type } = req.params;
  const yearNum = parseInt(year, 10);
  if (!VALID_TYPES.includes(type))
    return res.status(400).json({ error: 'Invalid type. Must be Building or Normal_Layout.' });
  if (isNaN(yearNum) || yearNum < 2010 || yearNum > CURRENT_YEAR + 1)
    return res.status(400).json({ error: 'Invalid year.' });

  const targetUrl = `https://rera.tn.gov.in/cms/reg_projects_tamilnadu/${type}/${year}.php`;
  const proxyReq  = https.get(targetUrl, {
    headers: {
      'User-Agent': BROWSER_UA,
      'Accept':     'text/html,*/*',
      'Referer':    'https://rera.tn.gov.in/',
    },
  }, (proxyRes) => {
    if (proxyRes.statusCode !== 200)
      return res.status(proxyRes.statusCode).json({ error: `TNRERA returned HTTP ${proxyRes.statusCode}` });
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    proxyRes.pipe(res);
  });
  proxyReq.setTimeout(25000, () => {
    proxyReq.destroy();
    if (!res.headersSent) res.status(504).json({ error: 'TNRERA request timed out' });
  });
  proxyReq.on('error', (err) => {
    if (!res.headersSent) res.status(502).json({ error: err.message });
  });
});

// ── Fetch + parse helpers ──────────────────────────────────────────────────────

function fetchHtml(type, year) {
  return new Promise((resolve, reject) => {
    const url = `https://rera.tn.gov.in/cms/reg_projects_tamilnadu/${type}/${year}.php`;
    const req = https.get(url, {
      headers: { 'User-Agent': BROWSER_UA, 'Accept': 'text/html,*/*', 'Referer': 'https://rera.tn.gov.in/' },
    }, (res) => {
      if (res.statusCode !== 200) { res.resume(); return reject(new Error(`HTTP ${res.statusCode}`)); }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      res.on('error', reject);
    });
    req.setTimeout(25000, () => { req.destroy(); reject(new Error('Timeout')); });
    req.on('error', reject);
  });
}

function stripTags(s) {
  return s.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ').trim();
}

function parseProjectTable(html) {
  const rows = [];

  // Find the header row to figure out column order
  const thPat   = /<th[^>]*>([\s\S]*?)<\/th>/gi;
  const headers  = [];
  let m;
  while ((m = thPat.exec(html)) !== null) headers.push(stripTags(m[1]).toLowerCase());

  // Column indices (flexible — works even if columns shift)
  const iReg  = headers.findIndex(h => h.includes('reg') || h.includes('rera'));
  const iName = headers.findIndex(h => h.includes('project') || h.includes('name'));
  const iDev  = headers.findIndex(h => h.includes('promot') || h.includes('developer') || h.includes('builder'));
  const iDist = headers.findIndex(h => h.includes('district'));
  const iStat = headers.findIndex(h => h.includes('status'));

  // Parse tbody rows
  const tbodyM = html.match(/<tbody[^>]*>([\s\S]*?)<\/tbody>/i);
  if (!tbodyM) return rows;

  const rowPat  = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowM;
  while ((rowM = rowPat.exec(tbodyM[1])) !== null) {
    const cellPat = /<td[^>]*>([\s\S]*?)<\/td>/gi;
    const cells   = [];
    let cellM;
    while ((cellM = cellPat.exec(rowM[1])) !== null) cells.push(stripTags(cellM[1]));
    if (cells.length < 3) continue;

    const pick = (idx) => (idx >= 0 && idx < cells.length ? cells[idx] : '') || '';
    const reraNo = pick(iReg >= 0 ? iReg : 1);
    const name   = pick(iName >= 0 ? iName : 2);
    const dev    = pick(iDev >= 0 ? iDev : 3);
    const dist   = pick(iDist >= 0 ? iDist : 4);
    const status = pick(iStat >= 0 ? iStat : 5);

    if (!name && !reraNo) continue;

    const nameKey = (name || reraNo).replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30);
    const distKey = dist.replace(/[^a-zA-Z0-9]/g, '_').slice(0, 20);
    rows.push({
      id:          `rera_${nameKey}_${distKey}`,
      projectName: name || reraNo,
      developer:   dev,
      district:    dist,
      reraNo,
      status:      status || 'Registered',
    });
  }
  return rows;
}

// ── GET /api/tnrera/projects?district=Chennai ──────────────────────────────────
// Returns parsed TNRERA project list as JSON for competitor intelligence.

router.get('/projects', async (req, res) => {
  const districtQuery = (req.query.district || '').toLowerCase()
    .replace(/\s*district\s*$/i, '').trim();

  const all    = [];
  const errors = [];

  for (const yr of [CURRENT_YEAR, CURRENT_YEAR - 1]) {
    for (const type of VALID_TYPES) {
      try {
        const html = await fetchHtml(type, yr);
        const rows = parseProjectTable(html);
        all.push(...rows);
      } catch (e) {
        errors.push(`${type}/${yr}: ${e.message}`);
      }
    }
  }

  // Deduplicate by RERA number
  const seen = new Map();
  for (const r of all) {
    if (!seen.has(r.reraNo)) seen.set(r.reraNo, r);
  }
  let projects = [...seen.values()];

  // Filter by district if provided
  if (districtQuery) {
    projects = projects.filter(p => {
      const d = p.district.toLowerCase();
      return d.includes(districtQuery) || districtQuery.includes(d);
    });
  }

  if (projects.length === 0) {
    return res.status(404).json({
      error:   `No TNRERA projects found${districtQuery ? ` for "${districtQuery}"` : ''}.`,
      details: errors.join(' | '),
    });
  }

  res.json(projects);
});

module.exports = router;
