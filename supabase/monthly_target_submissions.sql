-- Run this in your Supabase SQL Editor (safe to re-run).
--
-- Employee-submitted monthly targets that go through management approval.
-- Distinct from `monthly_targets` (the single management-set sites/deals number):
-- here an employee proposes per-category targets (Leads / Site Visits / Meetings
-- / Brokers) for a month, and management approves, rejects, or edits-then-approves.
--
-- Like the other tables, the app talks to Supabase with a shared company login,
-- so the policy allows BOTH anon and authenticated roles. Employee vs management
-- capability is enforced in the app, exactly as the other catalogs are.

CREATE TABLE IF NOT EXISTS monthly_target_submissions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period            TEXT NOT NULL,                     -- 'YYYY-MM'
  employee_email    TEXT NOT NULL DEFAULT '',
  employee_name     TEXT NOT NULL DEFAULT '',
  employee_code     TEXT NOT NULL DEFAULT '',          -- employee id / code
  department        TEXT NOT NULL DEFAULT '',
  designation       TEXT NOT NULL DEFAULT '',
  submitted_values  JSONB NOT NULL DEFAULT '{}'::jsonb, -- {leads, site_visits, meetings, brokers}
  approved_values   JSONB,                             -- set when management approves
  status            TEXT NOT NULL DEFAULT 'pending',   -- pending | approved | rejected
  management_edited BOOLEAN NOT NULL DEFAULT false,
  note              TEXT NOT NULL DEFAULT '',           -- employee note / rejection reason
  submitted_by      TEXT NOT NULL DEFAULT '',
  submitted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  edited_by         TEXT NOT NULL DEFAULT '',
  edited_at         TIMESTAMPTZ,
  approved_by       TEXT NOT NULL DEFAULT '',
  approved_at       TIMESTAMPTZ,
  -- Append-only audit of every transition: {at, by, action, from, to, values}.
  status_history    JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One submission per (month, employee); resubmitting after a rejection updates it.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'monthly_target_submissions_period_employee_key'
  ) THEN
    ALTER TABLE monthly_target_submissions
      ADD CONSTRAINT monthly_target_submissions_period_employee_key
      UNIQUE (period, employee_email);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_mts_period ON monthly_target_submissions(period DESC);
CREATE INDEX IF NOT EXISTS idx_mts_status ON monthly_target_submissions(status);

ALTER TABLE monthly_target_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage monthly target submissions" ON monthly_target_submissions;

CREATE POLICY "anyone can manage monthly target submissions"
  ON monthly_target_submissions FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
