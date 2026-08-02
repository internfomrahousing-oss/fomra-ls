-- =============================================================================
-- RLS LOCKDOWN, PART 2 (2026-08) — run AFTER rls_lockdown.sql.
--
-- rls_lockdown.sql only ever restricted land_leads, employee_profiles and
-- notifications to `authenticated`. Every other table still carried its
-- original setup-time "anyone can manage" policy with `anon` included,
-- meaning any internet visitor holding the public anon key (embedded in the
-- web build — not a secret) could read AND write AND delete legal documents,
-- signed-deal approval requests, site visits, call logs, meetings,
-- follow-ups, legal verifications, monthly targets, device push tokens, app
-- settings, and could read + forge audit log entries — with zero
-- authentication.
--
-- Also revokes anon EXECUTE on three now-dead legacy password-auth
-- functions (verify_account_password / set_account_password /
-- account_uses_default_password / _default_account_password /
-- generate_employee_id) that were reachable directly via the PostgREST RPC
-- endpoint with no rate limiting — a live credential-guessing oracle. These
-- functions are unused by the current app (superseded by real Supabase Auth
-- sessions); nothing in lib/ calls them.
--
-- Also restricts INSERT/UPDATE/DELETE on the land-lead-legal-docs and
-- profile-photos storage buckets to `authenticated` (previously anon could
-- overwrite/delete uploaded files). Read access on those buckets is left
-- open for now because the app fetches them via storage.getPublicUrl() —
-- see the TODO in land_lead_legal_service.dart / profile_photo_service.dart
-- to switch to signed URLs so read can be locked down too.
--
-- Applied directly to the production "FomraLS" project on 2026-08-02.
-- Safe to re-run; skips tables/functions that don't exist.
-- =============================================================================

do $$
begin
  if to_regprocedure('public.verify_account_password(text, text)') is not null then
    execute 'revoke execute on function public.verify_account_password(text, text) from anon, authenticated, public';
  end if;
  if to_regprocedure('public.set_account_password(text, text, text)') is not null then
    execute 'revoke execute on function public.set_account_password(text, text, text) from anon, authenticated, public';
  end if;
  if to_regprocedure('public.account_uses_default_password(text)') is not null then
    execute 'revoke execute on function public.account_uses_default_password(text) from anon, authenticated, public';
  end if;
  if to_regprocedure('public._default_account_password()') is not null then
    execute 'revoke execute on function public._default_account_password() from anon, authenticated, public';
  end if;
  if to_regprocedure('public.generate_employee_id()') is not null then
    execute 'revoke execute on function public.generate_employee_id() from anon';
  end if;
end $$;

do $$
begin
  if to_regclass('public.app_settings') is not null then
    execute 'drop policy if exists "anyone can manage app settings" on app_settings';
    execute 'drop policy if exists "authenticated can manage app_settings" on app_settings';
    execute 'create policy "authenticated can manage app_settings" on app_settings for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.audit_logs') is not null then
    execute 'drop policy if exists "audit_logs_insert" on audit_logs';
    execute 'drop policy if exists "audit_logs_select" on audit_logs';
    execute 'drop policy if exists "authenticated can insert audit_logs" on audit_logs';
    execute 'drop policy if exists "authenticated can read audit_logs" on audit_logs';
    execute 'create policy "authenticated can insert audit_logs" on audit_logs for insert to authenticated with check (true)';
    execute 'create policy "authenticated can read audit_logs" on audit_logs for select to authenticated using (true)';
  end if;

  if to_regclass('public.device_tokens') is not null then
    execute 'drop policy if exists "anyone can manage device tokens" on device_tokens';
    execute 'drop policy if exists "authenticated can manage device_tokens" on device_tokens';
    execute 'create policy "authenticated can manage device_tokens" on device_tokens for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.field_calendar_events') is not null then
    execute 'drop policy if exists "anyone can manage field_calendar_events" on field_calendar_events';
    execute 'drop policy if exists "authenticated can manage field_calendar_events" on field_calendar_events';
    execute 'create policy "authenticated can manage field_calendar_events" on field_calendar_events for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.land_lead_legal_documents') is not null then
    execute 'drop policy if exists "anyone can manage land_lead_legal_documents" on land_lead_legal_documents';
    execute 'drop policy if exists "authenticated can manage land_lead_legal_documents" on land_lead_legal_documents';
    execute 'create policy "authenticated can manage land_lead_legal_documents" on land_lead_legal_documents for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.land_lead_meetings') is not null then
    execute 'drop policy if exists "anyone can manage land_lead_meetings" on land_lead_meetings';
    execute 'drop policy if exists "authenticated can manage land_lead_meetings" on land_lead_meetings';
    execute 'create policy "authenticated can manage land_lead_meetings" on land_lead_meetings for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.land_lead_signed_requests') is not null then
    execute 'drop policy if exists "anyone can manage signed requests" on land_lead_signed_requests';
    execute 'drop policy if exists "authenticated can manage land_lead_signed_requests" on land_lead_signed_requests';
    execute 'create policy "authenticated can manage land_lead_signed_requests" on land_lead_signed_requests for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.land_lead_site_visits') is not null then
    execute 'drop policy if exists "anyone can manage land_lead_site_visits" on land_lead_site_visits';
    execute 'drop policy if exists "authenticated can manage land_lead_site_visits" on land_lead_site_visits';
    execute 'create policy "authenticated can manage land_lead_site_visits" on land_lead_site_visits for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.lead_call_logs') is not null then
    execute 'drop policy if exists "anyone can manage lead_call_logs" on lead_call_logs';
    execute 'drop policy if exists "authenticated can manage lead_call_logs" on lead_call_logs';
    execute 'create policy "authenticated can manage lead_call_logs" on lead_call_logs for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.lead_follow_ups') is not null then
    execute 'drop policy if exists "anyone can manage lead follow ups" on lead_follow_ups';
    execute 'drop policy if exists "authenticated can manage lead_follow_ups" on lead_follow_ups';
    execute 'create policy "authenticated can manage lead_follow_ups" on lead_follow_ups for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.legal_verifications') is not null then
    execute 'drop policy if exists "anyone can manage legal_verifications" on legal_verifications';
    execute 'drop policy if exists "authenticated can manage legal_verifications" on legal_verifications';
    execute 'create policy "authenticated can manage legal_verifications" on legal_verifications for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.monthly_target_submissions') is not null then
    execute 'drop policy if exists "anyone can manage monthly target submissions" on monthly_target_submissions';
    execute 'drop policy if exists "authenticated can manage monthly_target_submissions" on monthly_target_submissions';
    execute 'create policy "authenticated can manage monthly_target_submissions" on monthly_target_submissions for all to authenticated using (true) with check (true)';
  end if;

  if to_regclass('public.monthly_targets') is not null then
    execute 'drop policy if exists "anyone can manage monthly targets" on monthly_targets';
    execute 'drop policy if exists "authenticated can manage monthly_targets" on monthly_targets';
    execute 'create policy "authenticated can manage monthly_targets" on monthly_targets for all to authenticated using (true) with check (true)';
  end if;

  -- Legacy Express-backend tables (leads/profiles/tasks/site_visits) that
  -- still physically exist in this Postgres database even though the app no
  -- longer uses that backend. `profiles` still had a `public`-role (i.e.
  -- anon-inclusive) read policy from that era.
  if to_regclass('public.profiles') is not null then
    execute 'drop policy if exists "profiles_read" on profiles';
    execute 'drop policy if exists "profiles_write" on profiles';
    execute 'drop policy if exists "authenticated can read profiles" on profiles';
    execute 'create policy "authenticated can read profiles" on profiles for select to authenticated using (true)';
    execute 'create policy "users can insert own profile" on profiles for insert to authenticated with check (auth.uid() = id)';
  end if;
end $$;

-- ── Storage: restrict writes on legal-docs / profile-photos to authenticated ─
drop policy if exists "anyone can delete land lead legal docs" on storage.objects;
drop policy if exists "anyone can update land lead legal docs" on storage.objects;
drop policy if exists "anyone can upload land lead legal docs" on storage.objects;
create policy "authenticated can upload land lead legal docs" on storage.objects
  for insert to authenticated with check (bucket_id = 'land-lead-legal-docs');
create policy "authenticated can update land lead legal docs" on storage.objects
  for update to authenticated using (bucket_id = 'land-lead-legal-docs') with check (bucket_id = 'land-lead-legal-docs');
create policy "authenticated can delete land lead legal docs" on storage.objects
  for delete to authenticated using (bucket_id = 'land-lead-legal-docs');

drop policy if exists "profile photos write" on storage.objects;
create policy "authenticated can write profile photos" on storage.objects
  for all to authenticated using (bucket_id = 'profile-photos') with check (bucket_id = 'profile-photos');

-- ── Known remaining exception (intentional, documented) ──────────────────────
-- employee_profiles keeps an anon SELECT policy: the login screen must look
-- up which portal/name a typed email belongs to before a session exists.
-- Consider narrowing this to a view exposing only (id, full_name, status) —
-- phone/notes/designation don't need to be anon-readable — as a follow-up.
