-- EMERGENCY REVERT of rls_lockdown.sql — restores the previous open policies so
-- the app works again (anon + authenticated can read/write). Run this in the
-- Supabase SQL Editor. Safe to re-run; skips tables that don't exist.
--
-- Use this if the lockdown blocked normal use (e.g. "new row violates row-level
-- security policy"). We can re-apply the lockdown later once every login is
-- confirmed to establish a real authenticated session.

-- ── land_leads ───────────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.land_leads') is not null then
    execute 'drop policy if exists "authenticated can manage land_leads" on land_leads';
    execute 'drop policy if exists "anyone can manage land_leads" on land_leads';
    execute 'create policy "anyone can manage land_leads" on land_leads for all to anon, authenticated using (true) with check (true)';
  end if;
  if exists (select 1 from pg_proc where proname = 'generate_land_lead_id') then
    execute 'grant execute on function generate_land_lead_id() to anon, authenticated';
  end if;
end $$;

-- ── employee_profiles ────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.employee_profiles') is not null then
    execute 'drop policy if exists "read employee_profiles" on employee_profiles';
    execute 'drop policy if exists "authenticated can write employee_profiles" on employee_profiles';
    execute 'drop policy if exists "anyone can manage employee_profiles" on employee_profiles';
    execute 'create policy "anyone can manage employee_profiles" on employee_profiles for all to anon, authenticated using (true) with check (true)';
  end if;
end $$;

-- ── legal_verifications ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.legal_verifications') is not null then
    execute 'drop policy if exists "authenticated can manage legal_verifications" on legal_verifications';
    execute 'drop policy if exists "anyone can manage legal_verifications" on legal_verifications';
    execute 'create policy "anyone can manage legal_verifications" on legal_verifications for all to anon, authenticated using (true) with check (true)';
  end if;
end $$;

-- ── notifications ────────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.notifications') is not null then
    execute 'drop policy if exists "authenticated can manage notifications" on notifications';
    execute 'drop policy if exists "anyone can manage notifications" on notifications';
    execute 'create policy "anyone can manage notifications" on notifications for all to anon, authenticated using (true) with check (true)';
  end if;
end $$;

-- ── tngis_land_cache ─────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.tngis_land_cache') is not null then
    execute 'drop policy if exists "authenticated can manage tngis_land_cache" on tngis_land_cache';
    execute 'drop policy if exists "anyone can manage tngis_land_cache" on tngis_land_cache';
    execute 'create policy "anyone can manage tngis_land_cache" on tngis_land_cache for all to anon, authenticated using (true) with check (true)';
  end if;
end $$;

-- ── land-lead photos ─────────────────────────────────────────────────────────
do $$ begin
  if to_regclass('storage.objects') is not null then
    execute 'drop policy if exists "authenticated can upload land lead photos" on storage.objects';
    execute 'drop policy if exists "authenticated can update land lead photos" on storage.objects';
    execute 'drop policy if exists "authenticated can delete land lead photos" on storage.objects';
    execute 'drop policy if exists "anyone can upload land lead photos" on storage.objects';
    execute 'drop policy if exists "anyone can update land lead photos" on storage.objects';
    execute 'drop policy if exists "anyone can delete land lead photos" on storage.objects';
    execute 'create policy "anyone can upload land lead photos" on storage.objects for insert to anon, authenticated with check (bucket_id = ''land-lead-photos'')';
    execute 'create policy "anyone can update land lead photos" on storage.objects for update to anon, authenticated using (bucket_id = ''land-lead-photos'') with check (bucket_id = ''land-lead-photos'')';
    execute 'create policy "anyone can delete land lead photos" on storage.objects for delete to anon, authenticated using (bucket_id = ''land-lead-photos'')';
  end if;
end $$;
