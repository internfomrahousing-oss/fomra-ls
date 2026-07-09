-- Run this in your Supabase SQL Editor (safe to re-run).
-- FCM device registration tokens for push notifications (web + Android).
--
-- Like notifications, the app uses a shared per-portal login (no per-user
-- session), so tokens are keyed by AUDIENCE ('management' | 'employee'). When a
-- notifications row is inserted, the /api/push webhook sends an FCM push to
-- every token whose audience matches. user_name is stored (best-effort) so we
-- can later narrow employee pushes to a specific assignee.

CREATE TABLE IF NOT EXISTS device_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token      TEXT NOT NULL UNIQUE,                 -- FCM registration token
  audience   TEXT NOT NULL DEFAULT 'management',   -- management | employee
  user_name  TEXT,                                 -- best-effort signed-in name
  platform   TEXT NOT NULL DEFAULT 'web',          -- web | android | ios
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_audience
  ON device_tokens(audience);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage device tokens" ON device_tokens;

-- Same shared-login model as notifications: allow anon + authenticated. The
-- token itself is not sensitive (it only lets our server push to that device).
CREATE POLICY "anyone can manage device tokens"
  ON device_tokens FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
