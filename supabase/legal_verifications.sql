-- Run in Supabase SQL Editor (safe to re-run).
-- Stores per-lead legal verification data: document names and review answers.
-- Actual document files are session-only; only the file names are persisted.

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
  doc_sale_deed        TEXT        NOT NULL DEFAULT '',
  doc_parent_docs      TEXT        NOT NULL DEFAULT '',
  doc_power_of_attorney TEXT       NOT NULL DEFAULT '',
  doc_approval_docs    TEXT        NOT NULL DEFAULT '',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE legal_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can manage legal_verifications" ON legal_verifications;
CREATE POLICY "anyone can manage legal_verifications"
  ON legal_verifications FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
