const express = require('express');
const https   = require('https');
const router  = express.Router();
const {
  buildInfrastructureQuery,
  parseInfrastructureElements,
  computeInfrastructureScores,
} = require('../lib/overpassInfrastructure');

const MIRRORS = [
  { hostname: 'overpass-api.de',          path: '/api/interpreter' },
  { hostname: 'overpass.kumi.systems',    path: '/api/interpreter' },
  { hostname: 'overpass.openstreetmap.ru',path: '/api/interpreter' },
];

function queryMirror(mirror, body) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: mirror.hostname,
      path:     mirror.path,
      method:   'POST',
      headers:  {
        'Content-Type':   'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
        'User-Agent':     'FomraLS/1.0 (fomra.digital26@gmail.com)',
        'Accept':         'application/json',
      },
      timeout: 55000,
    };

    const req = https.request(options, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode} from ${mirror.hostname}`));
        }
        try {
          resolve(JSON.parse(raw));
        } catch (_) {
          reject(new Error(`Invalid JSON from ${mirror.hostname}`));
        }
      });
      res.on('error', reject);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Timeout from ${mirror.hostname}`));
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// POST /api/poi
// Body: { query: string }  — raw Overpass QL query string
router.post('/', async (req, res) => {
  const { query } = req.body;
  if (!query || typeof query !== 'string') {
    return res.status(400).json({ error: 'query field is required' });
  }

  const body = `data=${encodeURIComponent(query)}`;
  let lastErr = 'All Overpass mirrors failed';

  for (const mirror of MIRRORS) {
    try {
      const data = await queryMirror(mirror, body);
      return res.json(data);
    } catch (err) {
      lastErr = err.message;
      // try next mirror
    }
  }

  res.status(502).json({ error: lastErr });
});

async function runOverpassQuery(query) {
  const body = `data=${encodeURIComponent(query)}`;
  let lastErr = 'All Overpass mirrors failed';
  for (const mirror of MIRRORS) {
    try {
      return await queryMirror(mirror, body);
    } catch (err) {
      lastErr = err.message;
    }
  }
  const err = new Error(lastErr);
  err.status = 502;
  throw err;
}

// POST /api/poi/infrastructure
// Body: { lat, lon, radiusKm } — Overpass POI + highway scoring
router.post('/infrastructure', async (req, res) => {
  const lat = parseFloat(req.body?.lat);
  const lon = parseFloat(req.body?.lon);
  const radiusKm = parseInt(req.body?.radiusKm, 10) || 2;

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return res.status(400).json({ error: 'lat and lon are required' });
  }
  if (![2, 5, 10].includes(radiusKm)) {
    return res.status(400).json({ error: 'radiusKm must be 2, 5, or 10' });
  }

  try {
    const radiusMeters = radiusKm * 1000;
    const query = buildInfrastructureQuery(lat, lon, radiusMeters);
    const data = await runOverpassQuery(query);
    const elements = data.elements || [];

    if (data.remark && elements.length === 0) {
      return res.status(502).json({ error: String(data.remark) });
    }

    const { counts, places, roadCounts } = parseInfrastructureElements(elements, lat, lon);
    const scores = computeInfrastructureScores(counts, roadCounts, radiusKm);

    return res.json({
      source:    'OpenStreetMap Overpass API',
      lat,
      lon,
      radiusKm,
      counts,
      places,
      roadCounts,
      scores,
    });
  } catch (err) {
    return res.status(err.status || 502).json({ error: err.message });
  }
});

module.exports = router;
