-- Run this in your Supabase SQL Editor (safe to re-run).
--
-- Follow-up reminders an executive (or management) sets on a lead: a title,
-- optional notes, and a scheduled date/time. When the time passes, the client
-- reminder sync (NotificationCenterService.syncAlerts) turns each due, pending
-- follow-up into a `reminder` notification — panel + badge + toast — that links
-- back to the lead. No server scheduler is required.
--
-- Like the other tables, the app uses a shared company login, so the policy
-- allows anon + authenticated; who-sees-what is enforced in the app.

CREATE TABLE IF NOT EXISTS lead_follow_ups (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT NOT NULL,
  title            TEXT NOT NULL DEFAULT '',
  notes            TEXT NOT NULL DEFAULT '',
  remind_at        TIMESTAMPTZ NOT NULL,               -- scheduled date + time
  status           TEXT NOT NULL DEFAULT 'pending',    -- pending | completed
  created_by       TEXT NOT NULL DEFAULT '',
  created_by_email TEXT NOT NULL DEFAULT '',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_lead_follow_ups_lead ON lead_follow_ups(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_follow_ups_due
  ON lead_follow_ups(remind_at) WHERE status = 'pending';

ALTER TABLE lead_follow_ups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage lead follow ups" ON lead_follow_ups;

CREATE POLICY "anyone can manage lead follow ups"
  ON lead_follow_ups FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
