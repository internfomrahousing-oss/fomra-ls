-- Run this in your Supabase SQL Editor (safe to re-run).
-- In-app notifications for the notification bell.
--
-- Like land_leads, the app talks to Supabase with a shared company login, so the
-- policies below allow BOTH anon and authenticated roles. Notifications are
-- audience-based (there is no per-user session): a row with audience = 'management'
-- is shown to anyone signed in through the Management portal.

CREATE TABLE IF NOT EXISTS notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audience   TEXT NOT NULL DEFAULT 'management',        -- management | employee
  type       TEXT NOT NULL DEFAULT 'lead',              -- lead | task | document | alert | verification | site_visit
  title      TEXT NOT NULL,
  message    TEXT NOT NULL DEFAULT '',
  lead_id    TEXT,                                      -- references land_leads(id)
  reference_id TEXT,                                    -- optional linked record (e.g. site visit id)
  is_read    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS reference_id TEXT;

CREATE INDEX IF NOT EXISTS idx_notifications_audience_created
  ON notifications(audience, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage notifications" ON notifications;

CREATE POLICY "anyone can manage notifications"
  ON notifications FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Make sure the uploader-name column exists (see land_leads.sql).
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS created_by_name TEXT DEFAULT '';

-- New leads no longer notify management automatically.
-- See management_visit_approvals.sql for status-based notifications.

-- Enable realtime so the bell updates live. Ignore the error if it's already added.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
