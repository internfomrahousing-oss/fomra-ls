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

/** Strict radius filter — only projects inside radiusKm with map coordinates. */
function applyRadiusFilter(listings, lat, lng, radiusKm) {
  const latN = parseFloat(lat);
  const lngN = parseFloat(lng);
  const r = parseFloat(radiusKm);
  if (!Number.isFinite(latN) || !Number.isFinite(lngN) || !Number.isFinite(r) || r <= 0) {
    return { listings, radiusApplied: false };
  }

  const withCoords = listings.filter((l) => listingCoords(l));

  if (withCoords.length === 0) {
    return {
      listings: [],
      radiusApplied: true,
      radiusNote:
        `No projects could be mapped within ${r}km. `
        + 'Try a larger radius or tap closer to a city centre.',
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
    radiusNote: `No projects within ${r}km of this map point. Try 5km or 10km.`,
  };
}

/** Attach distanceKm and return nearest listings (priced fallback when strict radius is empty). */
function applyNearestListings(listings, lat, lng, maxCount = 30) {
  const latN = parseFloat(lat);
  const lngN = parseFloat(lng);
  if (!Number.isFinite(latN) || !Number.isFinite(lngN)) return [];

  return listings
    .map((l) => {
      const c = listingCoords(l);
      if (!c) return null;
      const dist = haversineKm(latN, lngN, c.lat, c.lng);
      return { ...l, distanceKm: Math.round(dist * 10) / 10 };
    })
    .filter(Boolean)
    .sort((a, b) => (a.distanceKm || 0) - (b.distanceKm || 0))
    .slice(0, maxCount);
}

module.exports = {
  applyRadiusFilter,
  applyNearestListings,
  haversineKm,
  listingCoords,
};
