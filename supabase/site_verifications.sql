-- Run in Supabase SQL Editor (safe to re-run).
-- Stores site verification form data submitted by the field team.
-- Photo/video files are session-only (not stored in DB); counts are stored.

CREATE TABLE IF NOT EXISTS site_verifications (
  id               TEXT        PRIMARY KEY,
  lead_id          TEXT        NOT NULL,
  geo_coordinates  TEXT        NOT NULL DEFAULT '',
  geo_address      TEXT        NOT NULL DEFAULT '',
  pincode          TEXT        NOT NULL DEFAULT '',
  road_access      TEXT        NOT NULL DEFAULT '',
  nearby_landmarks TEXT        NOT NULL DEFAULT '',
  site_observations TEXT       NOT NULL DEFAULT '',
  status           TEXT        NOT NULL DEFAULT 'completed',
  captured_on      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  photo_count      INT         NOT NULL DEFAULT 0,
  has_video        BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE site_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage site_verifications" ON site_verifications;
CREATE POLICY "anyone can manage site_verifications"
  ON site_verifications FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
