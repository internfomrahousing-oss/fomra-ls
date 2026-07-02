-- Run in Supabase SQL Editor (safe to re-run).
-- Shared persistent cache for TNGIS rate_limit_land_details (survey/sub per point).
--
-- The upstream endpoint is throttled per IP; the backend funnels every lookup
-- through one server IP and hits "Too many requests". Once any user resolves a
-- coordinate, the exact survey/sub is stored here and served to everyone,
-- surviving serverless cold starts and avoiding the throttle for repeat/near taps.

CREATE TABLE IF NOT EXISTS tngis_land_cache (
  coord_key  TEXT PRIMARY KEY,          -- "lat.5dp,lon.5dp"
  data       JSONB NOT NULL,            -- resolved land-details result
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE tngis_land_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage tngis_land_cache" ON tngis_land_cache;

CREATE POLICY "anyone can manage tngis_land_cache"
  ON tngis_land_cache FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
