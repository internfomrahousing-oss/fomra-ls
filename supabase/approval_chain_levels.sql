-- Run this in your Supabase SQL Editor (safe to re-run).
-- Multi-level approval routing: Executive -> Reporting Manager -> Head ->
-- Management. Each pending request records which level it currently sits at,
-- who it is waiting on, and who raised it (so a rejection can go back to them).
--
-- Defaults are chosen so EXISTING rows keep behaving exactly as before:
-- approval_level = 'management' means the original single-step flow.

-- Project Signed requests
ALTER TABLE land_lead_signed_requests
  ADD COLUMN IF NOT EXISTS approval_level TEXT NOT NULL DEFAULT 'management',
  ADD COLUMN IF NOT EXISTS pending_with TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS requested_by_email TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_signed_requests_pending_with
  ON land_lead_signed_requests(status, pending_with);

-- Management site visits
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS approval_level TEXT NOT NULL DEFAULT 'management',
  ADD COLUMN IF NOT EXISTS pending_with TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS requested_by_email TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_site_visits_pending_with
  ON land_lead_site_visits(approval_status, pending_with);
