-- Run this in your Supabase SQL Editor (safe to re-run).
-- Management sets monthly targets (number of sites/deals). A target is either
-- COMMON (employee_email = '', applies to every active employee) or PERSONAL
-- (employee_email = a specific employee). Each (month, employee) pair has at
-- most one target — saving the same pair again updates that row.
--
-- Like land_leads, the app talks to Supabase with a shared company login, so the
-- policy below allows BOTH anon and authenticated roles. Management-only access
-- is enforced in the app (the Settings tile and page are gated on isManagement),
-- exactly as the other management catalogs are.

CREATE TABLE IF NOT EXISTS monthly_targets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period          TEXT NOT NULL,                 -- 'YYYY-MM'
  employee_email  TEXT NOT NULL DEFAULT '',      -- '' = common (all employees)
  employee_name   TEXT NOT NULL DEFAULT '',      -- display label for a personal target
  target_count    INTEGER NOT NULL DEFAULT 0 CHECK (target_count >= 0),
  updated_by_name TEXT NOT NULL DEFAULT '',
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bring an older install (one-common-target-per-month) up to the per-employee
-- shape. All no-ops on a fresh table created above.
ALTER TABLE monthly_targets ADD COLUMN IF NOT EXISTS employee_email TEXT NOT NULL DEFAULT '';
ALTER TABLE monthly_targets ADD COLUMN IF NOT EXISTS employee_name  TEXT NOT NULL DEFAULT '';

-- Uniqueness is now per (month, employee): one common target plus one per named
-- employee. Replaces the old one-per-month UNIQUE(period). The auto-generated
-- name for `period TEXT ... UNIQUE` is monthly_targets_period_key.
ALTER TABLE monthly_targets DROP CONSTRAINT IF EXISTS monthly_targets_period_key;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'monthly_targets_period_employee_key'
  ) THEN
    ALTER TABLE monthly_targets
      ADD CONSTRAINT monthly_targets_period_employee_key UNIQUE (period, employee_email);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_monthly_targets_period
  ON monthly_targets(period DESC);

ALTER TABLE monthly_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage monthly targets" ON monthly_targets;

CREATE POLICY "anyone can manage monthly targets"
  ON monthly_targets FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
