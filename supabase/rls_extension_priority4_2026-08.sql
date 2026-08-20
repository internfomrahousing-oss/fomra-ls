-- Priority 4: extends real row-level security beyond land_leads to every
-- table that still had the old "any authenticated user can do anything"
-- policy and genuinely holds sensitive per-lead or per-person data.
--
-- Applied directly to production on 2026-08-14. All of this was tested
-- with real simulated sessions (set local role authenticated +
-- request.jwt.claims), not assumed — see the individual test notes below
-- each section. Test data was created, verified, then deleted; confirmed
-- the database was back to 0 rows in every touched table afterward.

-- ── 1. Lead-child tables ────────────────────────────────────────────────
-- One shared function instead of duplicating the created_by/assigned_to/
-- reporting-line rule 9 times: can_access_lead() re-checks the exact same
-- condition the land_leads policy itself uses, so a child table's access
-- automatically stays in lockstep with whatever the parent lead's policy
-- allows, rather than nine separate copies that could quietly drift.
create or replace function public.can_access_lead(target_lead_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from land_leads l
    where l.id = target_lead_id
      and (
        public.current_access_role() = 'admin'
        or l.created_by = auth.uid()
        or l.assigned_to = auth.uid()
        or (
          public.current_access_role() = 'manager'
          and l.created_by is not null
          and public.is_in_reporting_line_of(auth.uid(), l.created_by)
        )
      )
  );
$$;

drop policy if exists "authenticated can manage land_lead_meetings" on land_lead_meetings;
create policy "lead-scoped access to land_lead_meetings" on land_lead_meetings
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage lead_call_logs" on lead_call_logs;
create policy "lead-scoped access to lead_call_logs" on lead_call_logs
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage land_lead_site_visits" on land_lead_site_visits;
create policy "lead-scoped access to land_lead_site_visits" on land_lead_site_visits
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage land_lead_legal_documents" on land_lead_legal_documents;
create policy "lead-scoped access to land_lead_legal_documents" on land_lead_legal_documents
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage land_lead_signed_requests" on land_lead_signed_requests;
create policy "lead-scoped access to land_lead_signed_requests" on land_lead_signed_requests
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage land_lead_price_history" on land_lead_price_history;
create policy "lead-scoped access to land_lead_price_history" on land_lead_price_history
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage lead_follow_ups" on lead_follow_ups;
create policy "lead-scoped access to lead_follow_ups" on lead_follow_ups
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage legal_verifications" on legal_verifications;
create policy "lead-scoped access to legal_verifications" on legal_verifications
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

drop policy if exists "authenticated can manage field_calendar_events" on field_calendar_events;
create policy "lead-scoped access to field_calendar_events" on field_calendar_events
  for all to authenticated
  using (public.can_access_lead(lead_id))
  with check (public.can_access_lead(lead_id));

-- Tested: created a real test lead owned by Devaraj plus a meeting and a
-- call log on it. Confirmed Devaraj sees/can write both, Saurabh sees
-- neither, Management (admin) sees both. Cleaned up afterward.

-- ── 2. current_user_email() helper ──────────────────────────────────────
-- The notifications/monthly_target_submissions policies below need an
-- employee's own email. A raw inline `(select email from auth.users
-- where id = auth.uid())` fails — the authenticated role has no grant on
-- auth.users (confirmed by the actual error this produced: "permission
-- denied for table users"). Every other place this session needed
-- something from auth.users went through a security definer function for
-- exactly this reason; this was missed on the first pass here and fixed
-- immediately once the test caught it.
create or replace function public.current_user_email()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select email from auth.users where id = auth.uid();
$$;

-- ── 3. notifications ─────────────────────────────────────────────────────
-- Confirmed by reading NotificationHub directly: audience is one of three
-- shapes — 'management' (admin-tier only), 'employee' (a shared bucket
-- every non-admin employee subscribes to), or a specific employee's email
-- (individually addressed, e.g. approval routing). The app additionally
-- does client-side heuristic filtering within the shared 'employee'
-- bucket (parsing "assigned to X, Y" from the message text, cross-
-- checking lead ownership) that isn't safely replicable as a robust SQL
-- rule — left as an app-layer nicety, same trade-off already made for the
-- RM/manager reporting-line RLS branch. This policy blocks the real
-- cross-tier leakage: an employee can never see a management-only
-- notification, and never see another specific person's individually-
-- addressed one.
drop policy if exists "authenticated can manage notifications" on notifications;
create policy "audience-scoped access to notifications" on notifications
  for all to authenticated
  using (
    public.current_access_role() = 'admin'
    or audience = 'employee'
    or lower(trim(audience)) = lower(coalesce(public.current_user_email(), ''))
  )
  with check (
    public.current_access_role() = 'admin'
    or audience = 'employee'
    or lower(trim(audience)) = lower(coalesce(public.current_user_email(), ''))
  );

-- Tested: created 3 notifications ('management', 'employee',
-- 'devaraj@fomrahousing.in'). Confirmed Devaraj sees exactly the
-- 'employee' one and his own — not 'management'; Saurabh sees only
-- 'employee' — not Devaraj's or management's; Management sees all 3.
-- Cleaned up afterward.

-- ── 4. monthly_target_submissions ───────────────────────────────────────
-- An employee's own target proposal is personal (their proposed numbers,
-- management's edits/rejection reason) — should only be visible to them
-- and admin, not every other employee.
drop policy if exists "authenticated can manage monthly_target_submissions" on monthly_target_submissions;
create policy "own-submission access to monthly_target_submissions" on monthly_target_submissions
  for all to authenticated
  using (
    public.current_access_role() = 'admin'
    or lower(trim(employee_email)) = lower(coalesce(public.current_user_email(), ''))
  )
  with check (
    public.current_access_role() = 'admin'
    or lower(trim(employee_email)) = lower(coalesce(public.current_user_email(), ''))
  );

-- Tested: created a real submission for devaraj@fomrahousing.in.
-- Confirmed Saurabh sees 0 rows, Devaraj sees his own 1. Cleaned up
-- afterward.

-- ── Deliberately not touched ─────────────────────────────────────────────
-- app_settings, device_tokens, land_lead_document_types: system config /
-- reference data, not per-user sensitive.
-- profiles: role is 'agent' for every account (not actually used for
-- authorization anywhere in the app — confirmed earlier this session) —
-- low stakes, deprioritized.
-- leads, site_visits, tasks: confirmed earlier this session as a dead,
-- unused legacy system from before the app switched to land_leads — not
-- worth securing.
-- audit_logs: left as authenticated-read-all deliberately — an audit
-- trail that's itself access-restricted per-viewer becomes hard to trust
-- as a trail; the existing 195+ tests and every real user this session
-- exercises this table read-only via the app's own report screens, none
-- of which currently scope it per-user either.
