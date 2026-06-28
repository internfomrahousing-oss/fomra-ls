-- Run this in your Supabase SQL Editor (safe to re-run).
-- The app uses a shared company login that does NOT create a per-user Supabase
-- session, so the client talks to Supabase as the "anon" role. The policies
-- below therefore allow BOTH anon and authenticated roles to manage leads.

-- Simple global counter — lead IDs are 1, 2, 3, …
CREATE TABLE IF NOT EXISTS land_lead_counter (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  last_seq INT NOT NULL DEFAULT 0
);

INSERT INTO land_lead_counter (id, last_seq) VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;

-- Main land leads table
CREATE TABLE IF NOT EXISTS land_leads (
  id TEXT PRIMARY KEY,
  input_source TEXT NOT NULL,
  location TEXT DEFAULT '',
  gps_coordinates TEXT DEFAULT '',
  village TEXT DEFAULT '',
  taluk TEXT DEFAULT '',
  district TEXT DEFAULT '',
  pincode TEXT DEFAULT '',
  survey_number TEXT DEFAULT '',
  land_extent TEXT DEFAULT '',
  owner_name TEXT NOT NULL,
  contact_details TEXT DEFAULT '',
  land_type TEXT NOT NULL,
  road_width TEXT DEFAULT '',
  access_details TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'new_',
  added_on TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Generates sequential IDs: 1, 2, 3, …
CREATE OR REPLACE FUNCTION generate_land_lead_id()
RETURNS TEXT AS $$
DECLARE
  seq INT;
BEGIN
  INSERT INTO land_lead_counter (id, last_seq)
  VALUES (1, 1)
  ON CONFLICT (id) DO UPDATE
    SET last_seq = land_lead_counter.last_seq + 1
  RETURNING last_seq INTO seq;

  RETURN seq::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION generate_land_lead_id() TO anon, authenticated;

ALTER TABLE land_leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated can manage land_leads" ON land_leads;
DROP POLICY IF EXISTS "anyone can manage land_leads" ON land_leads;

CREATE POLICY "anyone can manage land_leads"
  ON land_leads FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
