-- ⚠️ DANGER: permanently deletes ALL land leads and restarts lead IDs at 1.
-- Run in the Supabase SQL Editor. There is no undo.

DELETE FROM land_leads;

-- Next new lead will get ID 1.
ALTER SEQUENCE IF EXISTS land_lead_id_seq RESTART WITH 1;

-- Clear the legacy yearly counter too (harmless if the table doesn't exist).
DO $$ BEGIN
  IF to_regclass('public.land_lead_year_counter') IS NOT NULL THEN
    EXECUTE 'DELETE FROM land_lead_year_counter';
  END IF;
END $$;

-- Note: old site photos remain in the storage bucket (orphaned but harmless).
