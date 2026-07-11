-- Run in Supabase SQL Editor (safe to re-run).
-- Stores landowner meeting logs for land leads.

CREATE TABLE IF NOT EXISTS land_lead_meetings (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  met_at           TIMESTAMPTZ NOT NULL,
  duration         TEXT        NOT NULL DEFAULT '',
  notes            TEXT        NOT NULL DEFAULT '',
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_land_lead_meetings_lead_id
  ON land_lead_meetings(lead_id);
CREATE INDEX IF NOT EXISTS idx_land_lead_meetings_met_at
  ON land_lead_meetings(met_at DESC);

ALTER TABLE land_lead_meetings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage land_lead_meetings" ON land_lead_meetings;
CREATE POLICY "anyone can manage land_lead_meetings"
  ON land_lead_meetings FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
