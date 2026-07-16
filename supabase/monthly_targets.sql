-- Run this in your Supabase SQL Editor (safe to re-run).
-- Management sets ONE common monthly target (number of sites/deals) that every
-- employee is measured against. A target belongs to a month, and each month has
-- at most one — selecting a new month creates a new row and leaves earlier
-- months untouched.
--
-- Like land_leads, the app talks to Supabase with a shared company login, so the
-- policy below allows BOTH anon and authenticated roles. Management-only access
-- is enforced in the app (the Settings tile and page are gated on isManagement),
-- exactly as the other management catalogs are.

CREATE TABLE IF NOT EXISTS monthly_targets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- 'YYYY-MM'. UNIQUE is what enforces "only one active target per month":
  -- saving the same month again updates that row instead of adding a second.
  period          TEXT NOT NULL UNIQUE,
  target_count    INTEGER NOT NULL DEFAULT 0 CHECK (target_count >= 0),
  updated_by_name TEXT NOT NULL DEFAULT '',
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_monthly_targets_period
  ON monthly_targets(period DESC);

ALTER TABLE monthly_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage monthly targets" ON monthly_targets;

CREATE POLICY "anyone can manage monthly targets"
  ON monthly_targets FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
