-- Generalizes the rename-approval pattern to the rest of a lead's core
-- info, per direct product decision: after the day a lead is saved,
-- editing or clearing an already-filled field needs management approval;
-- filling in a field that was blank never does, regardless of day.
--
-- Scoped to LandLeadService._auditedFields (owner_name, contact_details,
-- broker_name, broker_contact, land_extent, survey_number, sub_division,
-- village, taluk, district) — the fields this codebase already treats as
-- the meaningful, audit-worthy core info, distinct from status (its own
-- dedicated workflow already) and fields like GPS/photos/notes that
-- aren't the kind of "lead info" this rule is really about.
--
-- One row per edit submission holds every field that needs approval
-- together (a JSONB map of field -> {old, new, label}), rather than one
-- row per field.
--
-- Applied directly to production on 2026-08-22. Tested end-to-end with
-- real data before any app code shipped: created a test lead saved 2
-- days ago, confirmed a blank->filled field (taluk) applied directly
-- while an edited existing field (owner_name) stayed untouched pending
-- approval, confirmed approval applies the change, confirmed rejection
-- leaves the value completely untouched (never written in the first
-- place, so there's nothing to revert). Cleaned up all test data
-- afterward.
create table public.lead_change_requests (
  id uuid primary key default gen_random_uuid(),
  lead_id text not null references land_leads(id) on delete cascade,
  changes jsonb not null,
  requested_by uuid references auth.users(id),
  requested_by_name text not null default '',
  requested_by_email text not null default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by_name text not null default '',
  reviewed_at timestamptz,
  rejection_reason text not null default '',
  created_at timestamptz not null default now()
);

create index lead_change_requests_lead_id_idx on lead_change_requests(lead_id);

alter table lead_change_requests enable row level security;
create policy "lead-scoped access to lead_change_requests" on lead_change_requests
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));
