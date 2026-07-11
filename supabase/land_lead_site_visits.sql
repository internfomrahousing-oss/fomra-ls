-- Run in Supabase SQL Editor (safe to re-run).
-- Stores completed site visits for land leads.

CREATE TABLE IF NOT EXISTS land_lead_site_visits (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  visited_at       TIMESTAMPTZ NOT NULL,
  visit_type       TEXT        NOT NULL DEFAULT 'employee',
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  approval_status  TEXT        NOT NULL DEFAULT 'approved',
  management_notes TEXT        NOT NULL DEFAULT '',
  reviewed_at      TIMESTAMPTZ,
  reviewed_by_name TEXT        NOT NULL DEFAULT '',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS visit_type TEXT NOT NULL DEFAULT 'employee';
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved';
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS management_notes TEXT NOT NULL DEFAULT '';
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_land_lead_site_visits_lead_id
  ON land_lead_site_visits(lead_id);
CREATE INDEX IF NOT EXISTS idx_land_lead_site_visits_visited_at
  ON land_lead_site_visits(visited_at DESC);

ALTER TABLE land_lead_site_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage land_lead_site_visits" ON land_lead_site_visits;
CREATE POLICY "anyone can manage land_lead_site_visits"
  ON land_lead_site_visits FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
