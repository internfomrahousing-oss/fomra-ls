-- Run in Supabase SQL Editor (safe to re-run).
-- Supports up to 4 owners per site. Owner #1 stays in the existing
-- owner_name / contact_details columns for backward compatibility; owners
-- 2-4 (name + contact only) are stored as a JSON array here.

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS additional_owners JSONB NOT NULL DEFAULT '[]'::jsonb;
