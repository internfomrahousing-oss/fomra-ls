/**
 * Infrastructure scoring from OpenStreetMap via Overpass API.
 */

const POI_CATEGORIES = [
  { name: 'Schools',          tag: 'amenity', value: 'school',          groups: ['education'] },
  { name: 'Hospitals',        tag: 'amenity', value: 'hospital',        groups: ['health'] },
  { name: 'Railway Stations', tag: 'railway', value: 'station',         groups: ['transport'], excludeSubway: true },
  { name: 'Metro Stations',   tag: 'railway', value: 'station',         groups: ['transport'], requireSubway: true },
  { name: 'Bus Terminals',    tag: 'amenity', value: 'bus_station',     groups: ['transport'] },
  { name: 'IT Parks',         tag: 'office',  value: 'it',              groups: ['commercial'] },
  { name: 'Malls',            tag: 'shop',    value: 'mall',            groups: ['commercial'] },
  { name: 'Banks',            tag: 'amenity', value: 'bank',            groups: ['commercial'] },
  { name: 'Petrol Stations',  tag: 'amenity', value: 'fuel',            groups: ['amenity'] },
  { name: 'Govt. Offices',    tag: 'amenity', value: 'townhall',        groups: ['amenity'] },
  { name: 'Worship Places',   tag: 'amenity', value: 'place_of_worship', groups: ['amenity'] },
];

const HIGHWAY_TYPES = [
  'motorway', 'trunk', 'primary', 'secondary', 'tertiary',
  'unclassified', 'residential', 'living_street',
];

const HIGHWAY_WEIGHT = {
  motorway:      4,
  trunk:         3.5,
  primary:       3,
  secondary:     2,
  tertiary:      1.5,
  unclassified:  1,
  residential:   0.6,
  living_street: 0.4,
};

function buildInfrastructureQuery(lat, lon, radiusMeters) {
  const area = `(around:${radiusMeters},${lat},${lon})`;
  const parts = [];

  for (const cat of POI_CATEGORIES) {
    const filter = `["${cat.tag}"="${cat.value}"]`;
    if (cat.tag === 'landuse') {
      parts.push(`way${filter}${area};`);
    } else {
      parts.push(`node${filter}${area};`);
      parts.push(`way${filter}${area};`);
    }
  }

  for (const hw of HIGHWAY_TYPES) {
    parts.push(`way["highway"="${hw}"]${area};`);
  }

  return `[out:json][timeout:55];\n(\n${parts.join('\n')}\n);\nout tags center;`;
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const p = Math.PI / 180;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2
    + Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 2 * R * Math.asin(Math.sqrt(Math.max(0, a)));
}

function elementCoords(el) {
  if (el.lat != null && el.lon != null) {
    return { lat: Number(el.lat), lon: Number(el.lon) };
  }
  if (el.center?.lat != null && el.center?.lon != null) {
    return { lat: Number(el.center.lat), lon: Number(el.center.lon) };
  }
  return null;
}

function matchesCategory(tags, cat) {
  if (tags[cat.tag] !== cat.value) return false;
  if (cat.requireSubway && tags.station !== 'subway') return false;
  if (cat.excludeSubway && tags.station === 'subway') return false;
  return true;
}

function parseInfrastructureElements(elements, lat, lon) {
  const counts = {};
  const places = {};
  const roadCounts = {};

  for (const cat of POI_CATEGORIES) {
    counts[cat.name] = 0;
    places[cat.name] = [];
  }
  for (const hw of HIGHWAY_TYPES) {
    roadCounts[hw] = 0;
  }

  for (const el of elements || []) {
    const tags = el.tags || {};
    const hw = tags.highway;
    if (hw && roadCounts[hw] !== undefined) {
      roadCounts[hw] += 1;
      continue;
    }

    for (const cat of POI_CATEGORIES) {
      if (!matchesCategory(tags, cat)) continue;
      counts[cat.name] = (counts[cat.name] || 0) + 1;
      const name = String(tags.name || '').trim() || 'Unnamed';
      const coords = elementCoords(el);
      const entry = { name };
      if (coords) {
        entry.lat = coords.lat;
        entry.lon = coords.lon;
        entry.distance = Math.round(haversineKm(lat, lon, coords.lat, coords.lon) * 100) / 100;
      }
      places[cat.name].push(entry);
      break;
    }
  }

  for (const list of Object.values(places)) {
    list.sort((a, b) => (a.distance ?? 999) - (b.distance ?? 999));
  }

  return { counts, places, roadCounts };
}

function clampScore(value) {
  return Math.max(0, Math.min(100, Math.round(value * 10) / 10));
}

function countScore(count, max) {
  if (!max) return 0;
  return clampScore((count / max) * 100);
}

function roadConnectivityScore(roadCounts, radiusKm) {
  const major = ['motorway', 'trunk', 'primary', 'secondary', 'tertiary'];
  let weighted = 0;
  for (const hw of major) {
    weighted += (roadCounts[hw] || 0) * (HIGHWAY_WEIGHT[hw] || 1);
  }
  const maxW = radiusKm <= 2 ? 10 : radiusKm <= 5 ? 22 : 40;
  return clampScore((weighted / maxW) * 100);
}

function computeInfrastructureScores(counts, roadCounts, radiusKm) {
  const r = radiusKm;
  const maxEdu = r <= 2 ? 15 : r <= 5 ? 30 : 60;
  const maxHealth = r <= 2 ? 5 : r <= 5 ? 15 : 30;
  const maxCommercial = r <= 2 ? 10 : r <= 5 ? 25 : 50;
  const maxTransport = r <= 2 ? 8 : r <= 5 ? 20 : 40;

  const education = countScore(counts['Schools'] || 0, maxEdu);
  const healthcare = countScore(counts['Hospitals'] || 0, maxHealth);
  const transport = countScore(
    (counts['Railway Stations'] || 0)
    + (counts['Metro Stations'] || 0)
    + (counts['Bus Terminals'] || 0),
    maxTransport,
  );
  const commercial = countScore(
    (counts['Malls'] || 0) + (counts['Banks'] || 0) + (counts['IT Parks'] || 0),
    maxCommercial,
  );
  const road = roadConnectivityScore(roadCounts, r);
  const overall = clampScore(
    education * 0.25
    + healthcare * 0.25
    + transport * 0.20
    + commercial * 0.20
    + road * 0.10,
  );

  return {
    Education:          education,
    Healthcare:         healthcare,
    'Road Connectivity': road,
    Commercial:         commercial,
    Transport:          transport,
    'Overall Location': overall,
  };
}

module.exports = {
  POI_CATEGORIES,
  buildInfrastructureQuery,
  parseInfrastructureElements,
  computeInfrastructureScores,
};
