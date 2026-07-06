-- =============================================================================
-- RLS LOCKDOWN  —  run this LAST, only after:
--   1) every employee has a real auth login ("Provision logins for all"), and
--   2) the app is on the Stage 2 build (login uses the real Supabase session),
--      verified by an employee logging in with fomra@2024 in incognito.
--
-- What it does: removes the wide-open "anyone (anon) can manage" policies so the
-- public anon key can no longer read/modify/delete your data. Access now
-- requires a real authenticated session — which every provisioned user has.
--
-- This version is SAFE TO RE-RUN and SKIPS TABLES THAT DON'T EXIST (e.g. if a
-- feature like legal_verifications was never set up).
--
-- Two deliberate exceptions (required, or things break):
--   * employee_profiles keeps ANON *read* — login looks up the employee before
--     the session exists. (Anon can read the employee list; it cannot write.)
--   * land-lead photos keep ANON *read* — <img> tags can't send an auth token.
--     Uploads/edits/deletes are restricted to authenticated.
--
-- REVERSIBLE: to undo, re-run the original files (employees.sql, land_leads.sql,
-- notifications.sql, land_lead_photos.sql, …) which recreate the open policies.
-- =============================================================================

-- ── land_leads ───────────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.land_leads') is not null then
    execute 'drop policy if exists "anyone can manage land_leads" on land_leads';
    execute 'drop policy if exists "authenticated can manage land_leads" on land_leads';
    execute 'create policy "authenticated can manage land_leads" on land_leads for all to authenticated using (true) with check (true)';
  end if;
  if exists (select 1 from pg_proc where proname = 'generate_land_lead_id') then
    execute 'revoke execute on function generate_land_lead_id() from anon';
  end if;
end $$;

-- ── employee_profiles (anon may READ for login; only authenticated may write) ─
do $$ begin
  if to_regclass('public.employee_profiles') is not null then
    execute 'drop policy if exists "anyone can manage employee_profiles" on employee_profiles';
    execute 'drop policy if exists "read employee_profiles" on employee_profiles';
    execute 'drop policy if exists "authenticated can write employee_profiles" on employee_profiles';
    execute 'create policy "read employee_profiles" on employee_profiles for select to anon, authenticated using (true)';
    execute 'create policy "authenticated can write employee_profiles" on employee_profiles for all to authenticated using (true) with check (true)';
  end if;
end $$;

-- ── legal_verifications (skipped if the table was never created) ─────────────
do $$ begin
  if to_regclass('public.legal_verifications') is not null then
    execute 'drop policy if exists "anyone can manage legal_verifications" on legal_verifications';
    execute 'drop policy if exists "authenticated can manage legal_verifications" on legal_verifications';
    execute 'create policy "authenticated can manage legal_verifications" on legal_verifications for all to authenticated using (true) with check (true)';
  end if;
end $$;

-- ── notifications ────────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.notifications') is not null then
    execute 'drop policy if exists "anyone can manage notifications" on notifications';
    execute 'drop policy if exists "authenticated can manage notifications" on notifications';
    execute 'create policy "authenticated can manage notifications" on notifications for all to authenticated using (true) with check (true)';
  end if;
end $$;

-- ── tngis_land_cache (server backend writes via direct connection, bypassing RLS) ─
do $$ begin
  if to_regclass('public.tngis_land_cache') is not null then
    execute 'drop policy if exists "anyone can manage tngis_land_cache" on tngis_land_cache';
    execute 'drop policy if exists "authenticated can manage tngis_land_cache" on tngis_land_cache';
    execute 'create policy "authenticated can manage tngis_land_cache" on tngis_land_cache for all to authenticated using (true) with check (true)';
  end if;
end $$;

-- ── land-lead photos: keep public READ, restrict writes to authenticated ─────
do $$ begin
  if to_regclass('storage.objects') is not null then
    execute 'drop policy if exists "anyone can upload land lead photos" on storage.objects';
    execute 'drop policy if exists "anyone can update land lead photos" on storage.objects';
    execute 'drop policy if exists "anyone can delete land lead photos" on storage.objects';
    execute 'drop policy if exists "authenticated can upload land lead photos" on storage.objects';
    execute 'drop policy if exists "authenticated can update land lead photos" on storage.objects';
    execute 'drop policy if exists "authenticated can delete land lead photos" on storage.objects';
    execute 'create policy "authenticated can upload land lead photos" on storage.objects for insert to authenticated with check (bucket_id = ''land-lead-photos'')';
    execute 'create policy "authenticated can update land lead photos" on storage.objects for update to authenticated using (bucket_id = ''land-lead-photos'') with check (bucket_id = ''land-lead-photos'')';
    execute 'create policy "authenticated can delete land lead photos" on storage.objects for delete to authenticated using (bucket_id = ''land-lead-photos'')';
  end if;
end $$;
