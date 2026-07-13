-- Run in Supabase SQL Editor (safe to re-run).
-- Field Calendar events (site visits, meetings, surveys) with reminders.
-- Previously stored only in local SharedPreferences, which meant events were
-- invisible across devices/sessions and reminders could never reach the
-- shared Notification Center. Centralizing here fixes both.

CREATE TABLE IF NOT EXISTS field_calendar_events (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  kind                 TEXT        NOT NULL DEFAULT 'meeting', -- siteVisit | meeting | survey
  lead_id              TEXT        NOT NULL DEFAULT '',
  title                TEXT        NOT NULL DEFAULT '',
  scheduled_at         TIMESTAMPTZ NOT NULL,
  notes                TEXT        NOT NULL DEFAULT '',
  reminder_enabled     BOOLEAN     NOT NULL DEFAULT TRUE,
  remind_minutes       INTEGER     NOT NULL DEFAULT 60,
  completed            BOOLEAN     NOT NULL DEFAULT FALSE,
  created_by_name      TEXT        NOT NULL DEFAULT '',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_field_calendar_events_lead_id
  ON field_calendar_events(lead_id);
CREATE INDEX IF NOT EXISTS idx_field_calendar_events_scheduled_at
  ON field_calendar_events(scheduled_at);

ALTER TABLE field_calendar_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage field_calendar_events" ON field_calendar_events;
CREATE POLICY "anyone can manage field_calendar_events"
  ON field_calendar_events FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Enable realtime so both Field Calendar and reminder sync see live changes.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE field_calendar_events;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
