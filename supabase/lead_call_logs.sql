-- Run in Supabase SQL Editor (safe to re-run).
-- Stores employee call logs with landowners for land leads.

CREATE TABLE IF NOT EXISTS lead_call_logs (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  called_at        TIMESTAMPTZ NOT NULL,
  duration         TEXT        NOT NULL DEFAULT '',
  direction        TEXT        NOT NULL DEFAULT 'outgoing',
  details          TEXT        NOT NULL DEFAULT '',
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lead_call_logs_lead_id ON lead_call_logs(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_call_logs_called_at ON lead_call_logs(called_at DESC);

ALTER TABLE lead_call_logs
  ADD COLUMN IF NOT EXISTS direction TEXT NOT NULL DEFAULT 'outgoing';

ALTER TABLE lead_call_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage lead_call_logs" ON lead_call_logs;
CREATE POLICY "anyone can manage lead_call_logs"
  ON lead_call_logs FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
