-- Run this in your Supabase SQL Editor (safe to re-run).
-- Adds the org-hierarchy reporting line to employee profiles:
-- Executive -> Reporting Manager -> Head. `reports_to` stores the manager's
-- email (which equals employee_profiles.id). Empty when unassigned.

ALTER TABLE employee_profiles
  ADD COLUMN IF NOT EXISTS reports_to TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_employee_profiles_reports_to
  ON employee_profiles(reports_to);
