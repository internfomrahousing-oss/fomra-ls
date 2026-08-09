-- Foundation for real row-level security on land_leads. Until now, "who is
-- Management" was decided entirely client-side (which login portal was
-- used — see AuthService._portal in the Flutter app), which the database
-- has no way to check. This table makes it a real, stored fact instead.
--
-- Populated conservatively: an account is only ever marked with a *tighter*
-- tier than "admin" when I could directly confirm it from the roster.
-- Everyone else keeps full access (matching today's actual behavior for
-- every user, since no restriction exists yet at all) rather than risk
-- guessing someone into a role that regresses their real access.
--
-- Applied directly to production on 2026-08-09.
create table public.user_access_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'manager', 'executive')),
  notes text not null default '',
  updated_at timestamptz not null default now()
);

comment on table public.user_access_roles is
  'Real, DB-stored access tier per user — the missing piece an RLS policy '
  'needs. Not yet the single source of truth for the app itself (the '
  'Flutter app still decides UI-level access via login portal + '
  'employee_profiles.designation) — this exists so the database can also '
  'enforce a boundary, independent of the app.';

insert into public.user_access_roles (user_id, role, notes) values
  ('1068c542-7589-4155-ba9c-1fc504db542d', 'admin',
    'management@fomrahousing.in — the shared management-portal login, unambiguous.'),
  ('4aae0dd6-c112-42f5-9a31-3049ca189598', 'admin',
    'vijay@fomrahousing.in — kept as a real account during trial cleanup alongside management@; '
    'employee_profiles has no clear designation for them, so defaulting to admin rather than '
    'guessing a tighter tier that could regress real access. Revisit once confirmed.'),
  ('23a39731-7035-43f2-b868-b61f42b588b2', 'admin',
    'saurabh@fomrahousing.in — same reasoning as vijay: employee_profiles says plain Executive, '
    'but was treated as a trusted "keep" account during trial cleanup, same tier as management@. '
    'Defaulting to admin to avoid a regression; revisit once confirmed which is correct.'),
  ('a30b3f58-b336-4be6-9265-1d69e2580c3a', 'executive',
    'devaraj@fomrahousing.in — confirmed Executive via employee_profiles.designation, and has '
    'been treated as a plain field executive throughout this entire project.');

-- Every account not explicitly listed defaults to 'admin' (full access) —
-- the safe, non-regressing default until someone is deliberately reviewed
-- and given a tighter role. New employees should be added here explicitly
-- going forward.
create or replace function public.current_access_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.user_access_roles where user_id = auth.uid()),
    'admin'
  );
$$;

-- Recursive reporting-line check, mirroring TeamHierarchy.teamMemberEmails()
-- in the Flutter app exactly (same reports_to walk, same email-keyed join).
-- Not exercised by any real account today (nobody currently has a
-- Reporting Manager / Head designation in employee_profiles) but built
-- correctly now rather than left as a gap for whenever one is added.
create or replace function public.is_in_reporting_line_of(manager_uuid uuid, target_uuid uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  manager_email text;
  target_email text;
begin
  if manager_uuid = target_uuid then
    return true;
  end if;
  select email into manager_email from auth.users where id = manager_uuid;
  select email into target_email from auth.users where id = target_uuid;
  if manager_email is null or target_email is null then
    return false;
  end if;
  return exists (
    with recursive chain as (
      select lower(trim(email)) as email, lower(trim(reports_to)) as reports_to
      from employee_profiles
      where lower(trim(email)) = lower(trim(target_email))
      union all
      select ep.email, lower(trim(ep.reports_to))
      from employee_profiles ep
      join chain c on lower(trim(ep.email)) = c.reports_to
    )
    select 1 from chain where email = lower(trim(manager_email))
  );
end;
$$;
