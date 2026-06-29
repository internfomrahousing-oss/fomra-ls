-- Run in Supabase SQL Editor (safe to re-run).
-- Supports up to 4 site photos per lead + sub-division field.

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS sub_division TEXT DEFAULT '';

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS site_photo_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS site_photo_url TEXT DEFAULT '';

-- If only the legacy singular column has data, copy into the array.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'land_leads'
      AND column_name = 'site_photo_url'
  ) THEN
    UPDATE land_leads
    SET site_photo_urls = jsonb_build_array(site_photo_url)
    WHERE site_photo_url IS NOT NULL
      AND site_photo_url <> ''
      AND (site_photo_urls IS NULL OR site_photo_urls = '[]'::jsonb);
  END IF;
END $$;

-- If only the array has data, set singular column from first URL (app compat).
UPDATE land_leads
SET site_photo_url = site_photo_urls->>0
WHERE (site_photo_url IS NULL OR site_photo_url = '')
  AND site_photo_urls IS NOT NULL
  AND jsonb_typeof(site_photo_urls) = 'array'
  AND jsonb_array_length(site_photo_urls) > 0;
