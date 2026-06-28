-- Employee profiles (management creates; employees sign in with profile email).
-- Safe to re-run.

CREATE TABLE IF NOT EXISTS employee_profiles (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT DEFAULT '',
  designation TEXT DEFAULT '',
  department TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active',
  joined_on TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS employee_id_counter (
  year INT PRIMARY KEY,
  last_seq INT NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION generate_employee_id()
RETURNS TEXT AS $$
DECLARE
  curr_year  INT  := EXTRACT(YEAR FROM NOW())::INT;
  curr_month TEXT := LPAD(EXTRACT(MONTH FROM NOW())::TEXT, 2, '0');
  seq        INT;
BEGIN
  INSERT INTO employee_id_counter (year, last_seq)
  VALUES (curr_year, 1)
  ON CONFLICT (year) DO UPDATE
    SET last_seq = employee_id_counter.last_seq + 1
  RETURNING last_seq INTO seq;

  RETURN 'FE' || curr_month || curr_year::TEXT || LPAD(seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION generate_employee_id() TO anon, authenticated;

ALTER TABLE employee_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage employee_profiles" ON employee_profiles;

CREATE POLICY "anyone can manage employee_profiles"
  ON employee_profiles FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
