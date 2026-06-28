function haversineKm(lat1, lon1, lat2, lon2) {
  const p = Math.PI / 180;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2
    + Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 6371 * 2 * Math.asin(Math.sqrt(Math.max(0, a)));
}

function listingCoords(l) {
  const plat = parseFloat(l.lat);
  const plng = parseFloat(l.lng ?? l.lon);
  if (Number.isFinite(plat) && Number.isFinite(plng)) return { lat: plat, lng: plng };
  return null;
}

/**
 * Filter listings by radius when coordinates exist.
 * If none have coordinates, return city-wide results (common on Vercel/TNRERA).
 */
function applyRadiusFilter(listings, lat, lng, radiusKm) {
  const latN = parseFloat(lat);
  const lngN = parseFloat(lng);
  const r = parseFloat(radiusKm);
  if (!Number.isFinite(latN) || !Number.isFinite(lngN) || !Number.isFinite(r) || r <= 0) {
    return { listings, radiusApplied: false };
  }

  const withCoords = [];
  const withoutCoords = [];
  for (const l of listings) {
    if (listingCoords(l)) withCoords.push(l);
    else withoutCoords.push(l);
  }

  if (withCoords.length === 0) {
    return {
      listings,
      radiusApplied: false,
      radiusNote:
        'Project map locations unavailable — showing city-wide results. '
        + 'Radius filter applies when coordinates are available.',
    };
  }

  const inRadius = withCoords
    .map((l) => {
      const c = listingCoords(l);
      const dist = haversineKm(latN, lngN, c.lat, c.lng);
      if (dist > r) return null;
      return { ...l, distanceKm: Math.round(dist * 10) / 10 };
    })
    .filter(Boolean)
    .sort((a, b) => (a.distanceKm || 0) - (b.distanceKm || 0));

  if (inRadius.length > 0) {
    return { listings: inRadius, radiusApplied: true };
  }

  return {
    listings: [],
    radiusApplied: true,
    radiusNote: `No projects with map coordinates within ${r}km of this point.`,
  };
}

module.exports = { applyRadiusFilter, haversineKm, listingCoords };
