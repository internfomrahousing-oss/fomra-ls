-- Run this in your Supabase SQL Editor (safe to re-run).
-- "Project Signed" approval workflow: an employee submits a lead to be marked
-- Signed (with supporting photos/documents). The request stays pending until
-- management approves it, at which point the app flips the lead to Signed.
--
-- Like land_leads, the app talks to Supabase with a shared company login, so the
-- policy below allows BOTH anon and authenticated roles.

CREATE TABLE IF NOT EXISTS land_lead_signed_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id           TEXT NOT NULL,                        -- references land_leads(id)
  requested_by      UUID,                                 -- auth.users id (optional)
  requested_by_name TEXT NOT NULL DEFAULT '',
  note              TEXT NOT NULL DEFAULT '',
  photo_urls        JSONB NOT NULL DEFAULT '[]'::jsonb,   -- list of uploaded file URLs
  status            TEXT NOT NULL DEFAULT 'pending',      -- pending | approved | rejected
  reviewed_at       TIMESTAMPTZ,
  reviewed_by_name  TEXT NOT NULL DEFAULT '',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_signed_requests_status_created
  ON land_lead_signed_requests(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_signed_requests_lead
  ON land_lead_signed_requests(lead_id);

ALTER TABLE land_lead_signed_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage signed requests" ON land_lead_signed_requests;

CREATE POLICY "anyone can manage signed requests"
  ON land_lead_signed_requests FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Enable realtime (optional). Ignore the error if already added.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE land_lead_signed_requests;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
