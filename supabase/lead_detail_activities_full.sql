-- =============================================================================
-- FomraLS — Lead detail activities (run entire file in Supabase SQL Editor)
-- Safe to re-run. Creates missing tables/columns + RLS policies.
--
-- What this powers:
--   • Calls (outgoing/incoming, answered/not answered) → lead_call_logs
--   • Site visit + Management site visit → land_lead_site_visits
--   • Meeting logs → land_lead_meetings
--   • Legal uploads + reference notes → land_lead_legal_documents, legal_verifications
--   • Terms / deal details → land_leads.access_details
--   • Notes on lead → land_leads.notes
--   • Site photos → land_leads.site_photo_urls
--   • Broker fields → land_leads.broker_name, broker_contact
-- Activity summary counts are computed from call + visit rows (no counter table).
-- =============================================================================

-- ── 1. Core land_leads (skip if you already ran supabase/land_leads.sql) ───────

CREATE TABLE IF NOT EXISTS land_lead_year_counter (
  year INT PRIMARY KEY,
  last_seq INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS land_leads (
  id TEXT PRIMARY KEY,
  input_source TEXT NOT NULL,
  location TEXT DEFAULT '',
  gps_coordinates TEXT DEFAULT '',
  village TEXT DEFAULT '',
  taluk TEXT DEFAULT '',
  district TEXT DEFAULT '',
  pincode TEXT DEFAULT '',
  survey_number TEXT DEFAULT '',
  sub_division TEXT DEFAULT '',
  land_extent TEXT DEFAULT '',
  owner_name TEXT NOT NULL,
  contact_details TEXT DEFAULT '',
  land_type TEXT NOT NULL,
  road_width TEXT DEFAULT '',
  access_details TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  site_photo_url TEXT DEFAULT '',
  site_photo_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
  broker_name TEXT DEFAULT '',
  broker_contact TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'new_',
  added_on TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  created_by_name TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS created_by_name TEXT DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS sub_division TEXT DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS site_photo_urls JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS broker_name TEXT DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS broker_contact TEXT DEFAULT '';

ALTER TABLE land_leads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can manage land_leads" ON land_leads;
CREATE POLICY "anyone can manage land_leads"
  ON land_leads FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- ── 2. Call logs (Calls quick action) ────────────────────────────────────────
-- direction: 'outgoing' | 'incoming'
-- outcome:  'answered' | 'not_answered'

CREATE TABLE IF NOT EXISTS lead_call_logs (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  called_at        TIMESTAMPTZ NOT NULL,
  duration         TEXT        NOT NULL DEFAULT '',
  direction        TEXT        NOT NULL DEFAULT 'outgoing',
  outcome          TEXT        NOT NULL DEFAULT 'answered',
  details          TEXT        NOT NULL DEFAULT '',
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE lead_call_logs ADD COLUMN IF NOT EXISTS direction TEXT NOT NULL DEFAULT 'outgoing';
ALTER TABLE lead_call_logs ADD COLUMN IF NOT EXISTS outcome TEXT NOT NULL DEFAULT 'answered';

CREATE INDEX IF NOT EXISTS idx_lead_call_logs_lead_id ON lead_call_logs(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_call_logs_called_at ON lead_call_logs(called_at DESC);

ALTER TABLE lead_call_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can manage lead_call_logs" ON lead_call_logs;
CREATE POLICY "anyone can manage lead_call_logs"
  ON lead_call_logs FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- ── 3. Site visits (Site visit + Management site visit) ──────────────────────
-- visit_type: 'employee' | 'management'

CREATE TABLE IF NOT EXISTS land_lead_site_visits (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  visited_at       TIMESTAMPTZ NOT NULL,
  visit_type       TEXT        NOT NULL DEFAULT 'employee',
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE land_lead_site_visits ADD COLUMN IF NOT EXISTS visit_type TEXT NOT NULL DEFAULT 'employee';

CREATE INDEX IF NOT EXISTS idx_land_lead_site_visits_lead_id ON land_lead_site_visits(lead_id);
CREATE INDEX IF NOT EXISTS idx_land_lead_site_visits_visited_at ON land_lead_site_visits(visited_at DESC);

ALTER TABLE land_lead_site_visits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can manage land_lead_site_visits" ON land_lead_site_visits;
CREATE POLICY "anyone can manage land_lead_site_visits"
  ON land_lead_site_visits FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- ── 4. Meetings (Meeting quick action) ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS land_lead_meetings (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  met_at           TIMESTAMPTZ NOT NULL,
  duration         TEXT        NOT NULL DEFAULT '',
  notes            TEXT        NOT NULL DEFAULT '',
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_land_lead_meetings_lead_id ON land_lead_meetings(lead_id);
CREATE INDEX IF NOT EXISTS idx_land_lead_meetings_met_at ON land_lead_meetings(met_at DESC);

ALTER TABLE land_lead_meetings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can manage land_lead_meetings" ON land_lead_meetings;
CREATE POLICY "anyone can manage land_lead_meetings"
  ON land_lead_meetings FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- ── 5. Legal (Legal quick action) ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS legal_verifications (
  lead_id              TEXT        PRIMARY KEY,
  ownership            TEXT        NOT NULL DEFAULT '',
  mortgage             TEXT        NOT NULL DEFAULT '',
  mortgage_reason      TEXT        NOT NULL DEFAULT '',
  court_cases          TEXT        NOT NULL DEFAULT '',
  court_reason         TEXT        NOT NULL DEFAULT '',
  govt_risk            TEXT        NOT NULL DEFAULT '',
  govt_risk_reason     TEXT        NOT NULL DEFAULT '',
  title_chain          TEXT        NOT NULL DEFAULT '',
  encumbrances         TEXT        NOT NULL DEFAULT '',
  doc_validity         TEXT        NOT NULL DEFAULT '',
  legal_result         TEXT        NOT NULL DEFAULT '',
  legal_result_notes   TEXT        NOT NULL DEFAULT '',
  reference_notes      TEXT        NOT NULL DEFAULT '',
  doc_sale_deed        TEXT        NOT NULL DEFAULT '',
  doc_parent_docs      TEXT        NOT NULL DEFAULT '',
  doc_power_of_attorney TEXT       NOT NULL DEFAULT '',
  doc_approval_docs    TEXT        NOT NULL DEFAULT '',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE legal_verifications ADD COLUMN IF NOT EXISTS reference_notes TEXT NOT NULL DEFAULT '';

ALTER TABLE legal_verifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can manage legal_verifications" ON legal_verifications;
CREATE POLICY "anyone can manage legal_verifications"
  ON legal_verifications FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS land_lead_legal_documents (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id          TEXT        NOT NULL,
  file_name        TEXT        NOT NULL DEFAULT '',
  file_url         TEXT        NOT NULL DEFAULT '',
  verified_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  logged_by_name   TEXT        NOT NULL DEFAULT '',
  logged_by        UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_land_lead_legal_documents_lead_id ON land_lead_legal_documents(lead_id);
CREATE INDEX IF NOT EXISTS idx_land_lead_legal_documents_verified_at ON land_lead_legal_documents(verified_at DESC);

ALTER TABLE land_lead_legal_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can manage land_lead_legal_documents" ON land_lead_legal_documents;
CREATE POLICY "anyone can manage land_lead_legal_documents"
  ON land_lead_legal_documents FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

INSERT INTO storage.buckets (id, name, public)
VALUES ('land-lead-legal-docs', 'land-lead-legal-docs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "anyone can read land lead legal docs" ON storage.objects;
DROP POLICY IF EXISTS "anyone can upload land lead legal docs" ON storage.objects;
DROP POLICY IF EXISTS "anyone can update land lead legal docs" ON storage.objects;
DROP POLICY IF EXISTS "anyone can delete land lead legal docs" ON storage.objects;

CREATE POLICY "anyone can read land lead legal docs"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'land-lead-legal-docs');

CREATE POLICY "anyone can upload land lead legal docs"
  ON storage.objects FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'land-lead-legal-docs');

CREATE POLICY "anyone can update land lead legal docs"
  ON storage.objects FOR UPDATE TO anon, authenticated
  USING (bucket_id = 'land-lead-legal-docs')
  WITH CHECK (bucket_id = 'land-lead-legal-docs');

CREATE POLICY "anyone can delete land lead legal docs"
  ON storage.objects FOR DELETE TO anon, authenticated
  USING (bucket_id = 'land-lead-legal-docs');

-- ── Done ─────────────────────────────────────────────────────────────────────
-- Verify:
--   SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public'
--     AND table_name IN (
--       'land_leads', 'lead_call_logs', 'land_lead_site_visits',
--       'land_lead_meetings', 'land_lead_legal_documents', 'legal_verifications'
--     );
