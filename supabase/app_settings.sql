-- Run this in your Supabase SQL Editor (safe to re-run).
--
-- Org-wide feature toggles controlled from Settings › Feature Controls.
-- Keys used by the app:
--   manual_gps_entry          — allow typed / map-pin GPS on Add Lead
--   camera_only_site_photos   — when true, site photos must use the camera
--   role_hierarchy            — Emp → RM → Head → Management approval chain
--
-- Like the other catalogs, the app talks to Supabase with a shared company
-- login, so the policy allows BOTH anon and authenticated roles. Management-
-- only editing is enforced in the app.

CREATE TABLE IF NOT EXISTS app_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL DEFAULT 'false'::jsonb,
  updated_by  TEXT NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage app settings" ON app_settings;

CREATE POLICY "anyone can manage app settings"
  ON app_settings FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Defaults (ON for hierarchy + camera-only; OFF for manual GPS).
-- DO NOTHING on conflict so later Feature Controls toggles are preserved.
INSERT INTO app_settings (key, value) VALUES
  ('manual_gps_entry', 'false'::jsonb),
  ('camera_only_site_photos', 'true'::jsonb),
  ('role_hierarchy', 'true'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Helpful check after toggling in the app:
--   SELECT key, value, updated_at, updated_by FROM app_settings ORDER BY key;
