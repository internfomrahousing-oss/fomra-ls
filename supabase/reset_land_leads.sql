-- Run once in Supabase SQL Editor to delete all leads and reset numbering to 1.
-- Safe to re-run.

DELETE FROM land_leads;

CREATE TABLE IF NOT EXISTS land_lead_counter (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  last_seq INT NOT NULL DEFAULT 0
);

INSERT INTO land_lead_counter (id, last_seq) VALUES (1, 0)
ON CONFLICT (id) DO UPDATE SET last_seq = 0;

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
