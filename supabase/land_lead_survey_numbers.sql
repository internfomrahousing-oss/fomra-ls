-- Run in Supabase SQL Editor (safe to re-run).
-- Supports multiple survey numbers + sub-divisions per site. Entry #1 stays
-- in the existing survey_number / sub_division columns for backward
-- compatibility; entries 2+ are stored as a JSON array here, mirroring
-- land_lead_additional_owners.sql.

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS additional_survey_numbers JSONB NOT NULL DEFAULT '[]'::jsonb;
