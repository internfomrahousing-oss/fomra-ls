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
-- Two deliberate exceptions (required, or things break):
--   * employee_profiles keeps ANON *read* — login looks up the employee before
--     the session exists. (Anon can still read the employee list; it cannot
--     write. Tightening this further needs a login refactor.)
--   * land-lead photos keep ANON *read* — <img> tags can't send an auth token.
--     Uploads/edits/deletes are restricted to authenticated.
--
-- REVERSIBLE: to undo, re-run the original files (employees.sql, land_leads.sql,
-- legal_verifications.sql, notifications.sql, tngis_land_cache.sql,
-- land_lead_photos.sql), which recreate the anon+authenticated policies.
-- =============================================================================

-- ── land_leads ───────────────────────────────────────────────────────────────
drop policy if exists "anyone can manage land_leads" on land_leads;
drop policy if exists "authenticated can manage land_leads" on land_leads;
create policy "authenticated can manage land_leads"
  on land_leads for all
  to authenticated
  using (true) with check (true);
revoke execute on function generate_land_lead_id() from anon;

-- ── employee_profiles (anon may READ for login; only authenticated may write) ─
drop policy if exists "anyone can manage employee_profiles" on employee_profiles;
create policy "read employee_profiles"
  on employee_profiles for select
  to anon, authenticated
  using (true);
create policy "authenticated can write employee_profiles"
  on employee_profiles for all
  to authenticated
  using (true) with check (true);

-- ── legal_verifications ──────────────────────────────────────────────────────
drop policy if exists "anyone can manage legal_verifications" on legal_verifications;
create policy "authenticated can manage legal_verifications"
  on legal_verifications for all
  to authenticated
  using (true) with check (true);

-- ── notifications ────────────────────────────────────────────────────────────
drop policy if exists "anyone can manage notifications" on notifications;
create policy "authenticated can manage notifications"
  on notifications for all
  to authenticated
  using (true) with check (true);

-- ── tngis_land_cache (server backend writes via direct connection, bypassing RLS) ─
drop policy if exists "anyone can manage tngis_land_cache" on tngis_land_cache;
create policy "authenticated can manage tngis_land_cache"
  on tngis_land_cache for all
  to authenticated
  using (true) with check (true);

-- ── land-lead photos: keep public READ, restrict writes to authenticated ─────
drop policy if exists "anyone can upload land lead photos" on storage.objects;
drop policy if exists "anyone can update land lead photos" on storage.objects;
drop policy if exists "anyone can delete land lead photos" on storage.objects;
-- (the "anyone can read land lead photos" SELECT policy is intentionally kept)
create policy "authenticated can upload land lead photos"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'land-lead-photos');
create policy "authenticated can update land lead photos"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'land-lead-photos')
  with check (bucket_id = 'land-lead-photos');
create policy "authenticated can delete land lead photos"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'land-lead-photos');
