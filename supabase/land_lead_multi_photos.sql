-- Run in Supabase SQL Editor after land_lead_photos.sql
-- Supports up to 4 site photos per lead + sub-division field.

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS sub_division TEXT DEFAULT '';

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS site_photo_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Backfill: copy existing single photo into array when array is empty.
UPDATE land_leads
SET site_photo_urls = jsonb_build_array(site_photo_url)
WHERE site_photo_url IS NOT NULL
  AND site_photo_url <> ''
  AND (site_photo_urls IS NULL OR site_photo_urls = '[]'::jsonb);
