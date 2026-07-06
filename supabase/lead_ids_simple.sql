-- Simple sequential lead IDs: 1, 2, 3, …  (replaces the mmyyyy00001 format)
--
-- Run once in the Supabase SQL Editor. Affects NEW leads only — existing leads
-- keep their current IDs (renumbering them would orphan their stored photos,
-- which are saved under the old ID). Ask if you want a full, safe renumber.

CREATE SEQUENCE IF NOT EXISTS land_lead_id_seq START 1;

-- Continue the sequence after any existing short numeric IDs so new leads never
-- collide. (Old mmyyyy IDs are long and are ignored by the 1–6 digit filter.)
SELECT setval(
  'land_lead_id_seq',
  COALESCE(
    (SELECT MAX(id::bigint) FROM land_leads WHERE id ~ '^[0-9]{1,6}$'),
    0
  ) + 1,
  false
);

CREATE OR REPLACE FUNCTION generate_land_lead_id()
RETURNS TEXT AS $$
BEGIN
  RETURN nextval('land_lead_id_seq')::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION generate_land_lead_id() TO anon, authenticated;
