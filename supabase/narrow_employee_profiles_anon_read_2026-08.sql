-- employee_profiles was readable by anyone, including unauthenticated
-- visitors (roles: {anon, authenticated}). Verified no login/auth screen
-- depends on pre-login access to this table before making this change.
--
-- Applied directly to production on 2026-08-08.
drop policy if exists "read employee_profiles" on employee_profiles;

create policy "authenticated can read employee_profiles"
  on employee_profiles for select
  to authenticated
  using (true);
