-- Run in Supabase SQL Editor to delete all leads and reset numbering for the current year.
-- Safe to re-run. Next lead will be mmyyyy00001 (e.g. 06202600001).

DELETE FROM land_leads;

CREATE TABLE IF NOT EXISTS land_lead_year_counter (
  year INT PRIMARY KEY,
  last_seq INT NOT NULL DEFAULT 0
);

-- Reset counter for the current calendar year so the next lead is …00001
INSERT INTO land_lead_year_counter (year, last_seq)
VALUES (EXTRACT(YEAR FROM NOW())::INT, 0)
ON CONFLICT (year) DO UPDATE SET last_seq = 0;

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

  RETURN curr_month || curr_year::TEXT || LPAD(seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION generate_land_lead_id() TO anon, authenticated;
