-- =============================================================================
-- Land Sourcing Management improvements — foundation schema (2026-08).
-- Applied directly to production "FomraLS" on 2026-08-02, mirrored here for
-- version control. Entirely additive: new nullable columns + new tables.
-- Nothing existing is renamed/dropped/constrained, so this is safe to re-run
-- and does not require any app-side change to stay backward compatible.
--
-- Covers, from the Land Sourcing Module Review (2026-08):
--   #1/#11  Structured pricing/valuation fields + append-only price history
--   #2/#13  Reopen-after-drop tracking columns
--   #4/#15  Litigation / encumbrance / water / electricity / restrictions
--   #2 (lead mgmt) / improvements  Multi-broker support (additional_brokers)
--   #12 (trimmed)  Token Advance + Agreement milestones (Registration/
--                  Handover intentionally excluded — out of scope per
--                  management decision, see PR description)
--   #20     Split/merge lineage columns
--   #8      Mandatory document classification (land_lead_document_types)
-- =============================================================================

-- ── Pricing / valuation ────────────────────────────────────────────────────────
alter table land_leads
  add column if not exists asking_price numeric,
  add column if not exists expected_price numeric,
  add column if not exists guideline_value numeric,
  add column if not exists market_value_estimate numeric;

comment on column land_leads.asking_price is 'What the owner/broker is asking, in INR.';
comment on column land_leads.expected_price is 'Internal target/expected purchase price, in INR.';
comment on column land_leads.guideline_value is 'Government guideline/circle-rate value, in INR.';
comment on column land_leads.market_value_estimate is 'Comparable market value estimate, in INR (can be sourced from Market Intelligence).';

create table if not exists land_lead_price_history (
  id uuid primary key default gen_random_uuid(),
  lead_id text not null references land_leads(id) on delete cascade,
  price_type text not null check (price_type in ('asking','expected','offered','countered','final','guideline','market_estimate')),
  amount numeric,
  rate_per_acre numeric,
  notes text default '',
  recorded_by uuid,
  recorded_by_name text default '',
  recorded_at timestamptz not null default now()
);
create index if not exists idx_land_lead_price_history_lead on land_lead_price_history(lead_id, recorded_at desc);
alter table land_lead_price_history enable row level security;
drop policy if exists "authenticated can manage land_lead_price_history" on land_lead_price_history;
create policy "authenticated can manage land_lead_price_history" on land_lead_price_history
  for all to authenticated using (true) with check (true);

-- ── Risk / due-diligence fields ────────────────────────────────────────────────
alter table land_leads
  add column if not exists litigation_status text not null default 'unknown'
    check (litigation_status in ('unknown','none','suspected','confirmed','cleared')),
  add column if not exists encumbrance_status text not null default 'unknown'
    check (encumbrance_status in ('unknown','clear','encumbered','cleared')),
  add column if not exists water_availability text not null default 'unknown'
    check (water_availability in ('unknown','available','not_available')),
  add column if not exists electricity_availability text not null default 'unknown'
    check (electricity_availability in ('unknown','available','not_available')),
  add column if not exists government_restrictions text default '';

comment on column land_leads.government_restrictions is 'Free text: CRZ / conversion-pending / zoning notes etc. Structured tagging can follow once real usage patterns are seen.';

-- ── Multi-broker support — mirrors additional_owners ───────────────────────────
alter table land_leads
  add column if not exists additional_brokers jsonb not null default '[]'::jsonb;
comment on column land_leads.additional_brokers is 'Array of {name, contact} — same shape as additional_owners. broker_name/broker_contact stays as the primary broker.';

-- ── Token Advance + Agreement milestones (pre-signing only) ────────────────────
alter table land_leads
  add column if not exists token_advance_amount numeric,
  add column if not exists token_advance_date timestamptz,
  add column if not exists token_advance_notes text default '',
  add column if not exists agreement_status text not null default 'not_started'
    check (agreement_status in ('not_started','drafted','under_review','executed')),
  add column if not exists agreement_date timestamptz,
  add column if not exists agreement_notes text default '';

-- ── Reopen-after-drop tracking ──────────────────────────────────────────────────
alter table land_leads
  add column if not exists reopened_at timestamptz,
  add column if not exists reopened_by uuid,
  add column if not exists reopened_by_name text default '',
  add column if not exists reopen_reason text default '',
  add column if not exists reopen_count integer not null default 0;

-- ── Split / merge lineage ────────────────────────────────────────────────────────
alter table land_leads
  add column if not exists split_from_lead_id text references land_leads(id),
  add column if not exists merged_from_lead_ids jsonb not null default '[]'::jsonb;
comment on column land_leads.split_from_lead_id is 'Set when this lead was created by splitting off part of another lead.';
comment on column land_leads.merged_from_lead_ids is 'Array of lead IDs that were merged into this one (their records are kept, marked merged, not deleted).';

-- ── Mandatory document classification ────────────────────────────────────────────
create table if not exists land_lead_document_types (
  id text primary key,
  label text not null,
  is_required boolean not null default false,
  required_by_stage text,  -- e.g. 'legal' — the stage that should be blocked if missing
  sort_order integer not null default 0
);
alter table land_lead_document_types enable row level security;
drop policy if exists "authenticated can read land_lead_document_types" on land_lead_document_types;
drop policy if exists "authenticated can manage land_lead_document_types" on land_lead_document_types;
create policy "authenticated can read land_lead_document_types" on land_lead_document_types
  for select to authenticated using (true);
create policy "authenticated can manage land_lead_document_types" on land_lead_document_types
  for all to authenticated using (true) with check (true);

insert into land_lead_document_types (id, label, is_required, required_by_stage, sort_order) values
  ('ec', 'Encumbrance Certificate (EC)', true, 'legal', 1),
  ('patta', 'Patta', true, 'legal', 2),
  ('chitta_adangal', 'Chitta / Adangal', false, 'legal', 3),
  ('fmb_sketch', 'FMB Sketch', false, 'legal', 4),
  ('parent_document', 'Parent Document / Sale Deed', true, 'legal', 5),
  ('legal_heir_certificate', 'Legal Heir Certificate (if applicable)', false, 'legal', 6),
  ('power_of_attorney', 'Power of Attorney (if applicable)', false, 'legal', 7),
  ('tax_receipt', 'Property Tax Receipt', false, 'legal', 8),
  ('survey_sketch', 'Survey Sketch', false, 'legal', 9),
  ('agreement_draft', 'Agreement Draft', true, 'signed', 10),
  ('rtc_extract', 'RTC / Land Records Extract', false, 'legal', 11)
on conflict (id) do nothing;

alter table land_lead_legal_documents
  add column if not exists document_type_id text references land_lead_document_types(id);
