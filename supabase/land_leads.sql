-- Run this in your Supabase SQL Editor

-- Counter table for yearly sequential IDs
CREATE TABLE IF NOT EXISTS land_lead_year_counter (
  year INT PRIMARY KEY,
  last_seq INT NOT NULL DEFAULT 0
);

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
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Function generates IDs in format LLmmyyyy00001
-- Sequential counter resets each calendar year
CREATE OR REPLACE FUNCTION generate_land_lead_id()
RETURNS TEXT AS $$
DECLARE
  curr_year  INT  := EXTRACT(YEAR  FROM NOW())::INT;
  curr_month TEXT := LPAD(EXTRACT(MONTH FROM NOW())::TEXT, 2, '0');
  seq        INT;
BEGIN
  INSERT INTO land_lead_year_counter (year, last_seq)
  VALUES (curr_year, 1)
  ON CONFLICT (year) DO UPDATE
    SET last_seq = land_lead_year_counter.last_seq + 1
  RETURNING last_seq INTO seq;

  RETURN 'LL' || curr_month || curr_year::TEXT || LPAD(seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE land_leads ENABLE ROW LEVEL SECURITY;

-- Authenticated users can manage all land leads
CREATE POLICY "authenticated can manage land_leads"
  ON land_leads FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
