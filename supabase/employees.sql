-- Employee profiles (management creates; employees sign in with profile email).
-- Safe to re-run. Internal id is the employee email (not shown in the app UI).

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

ALTER TABLE employee_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage employee_profiles" ON employee_profiles;

CREATE POLICY "anyone can manage employee_profiles"
  ON employee_profiles FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
