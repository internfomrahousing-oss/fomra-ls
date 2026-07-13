-- Run once in the Supabase SQL Editor. Safe to re-run (idempotent).
-- Combines: lead_drop_reason.sql + land_lead_legal_docs.sql
-- Fixes the "drop_notes column not found" status error AND enables document uploads.

-- ============================================================
-- 1. Drop reason / notes columns (status update fix)
-- ============================================================
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS drop_reason TEXT NOT NULL DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS drop_notes  TEXT NOT NULL DEFAULT '';

-- ============================================================
-- 2. Legal / lead documents (upload + Documents tab)
-- ============================================================
ALTER TABLE legal_verifications
  ADD COLUMN IF NOT EXISTS reference_notes TEXT NOT NULL DEFAULT '';

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

CREATE INDEX IF NOT EXISTS idx_land_lead_legal_documents_lead_id
  ON land_lead_legal_documents(lead_id);
CREATE INDEX IF NOT EXISTS idx_land_lead_legal_documents_verified_at
  ON land_lead_legal_documents(verified_at DESC);

ALTER TABLE land_lead_legal_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage land_lead_legal_documents"
  ON land_lead_legal_documents;
CREATE POLICY "anyone can manage land_lead_legal_documents"
  ON land_lead_legal_documents FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- 3. Storage bucket + policies (holds the compressed files)
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('land-lead-legal-docs', 'land-lead-legal-docs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "anyone can read land lead legal docs" ON storage.objects;
DROP POLICY IF EXISTS "anyone can upload land lead legal docs" ON storage.objects;
DROP POLICY IF EXISTS "anyone can update land lead legal docs" ON storage.objects;
DROP POLICY IF EXISTS "anyone can delete land lead legal docs" ON storage.objects;

CREATE POLICY "anyone can read land lead legal docs"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'land-lead-legal-docs');

CREATE POLICY "anyone can upload land lead legal docs"
  ON storage.objects FOR INSERT
  TO anon, authenticated
  WITH CHECK (bucket_id = 'land-lead-legal-docs');

CREATE POLICY "anyone can update land lead legal docs"
  ON storage.objects FOR UPDATE
  TO anon, authenticated
  USING (bucket_id = 'land-lead-legal-docs')
  WITH CHECK (bucket_id = 'land-lead-legal-docs');

CREATE POLICY "anyone can delete land lead legal docs"
  ON storage.objects FOR DELETE
  TO anon, authenticated
  USING (bucket_id = 'land-lead-legal-docs');

-- ============================================================
-- 4. Refresh PostgREST schema cache so new columns are visible immediately
-- ============================================================
NOTIFY pgrst, 'reload schema';
