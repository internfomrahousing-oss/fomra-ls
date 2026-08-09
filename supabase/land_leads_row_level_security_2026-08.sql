-- Replaces the single "any authenticated user can do anything" policy with
-- real row-level access: admin sees/edits everything (matches every
-- current user's actual access exactly, per user_access_roles), an
-- executive only their own (created_by = auth.uid() — matches
-- LeadVisibility's "every Executive always just their own sites" rule in
-- the Flutter app exactly), a manager their own reporting line (built and
-- correct, not exercised by any real account today — nobody currently has
-- a Reporting Manager/Head designation).
--
-- Verified before applying, not assumed: checked every current row's
-- created_by against auth.users (0 orphaned), checked the 2 NULL-created_by
-- rows individually (both belong to an admin-tier user, so the admin
-- bypass covers them — no row silently disappears for anyone who
-- currently sees it). After applying, simulated real sessions
-- (set local role authenticated + request.jwt.claims) for both an
-- executive and an admin account and confirmed the exact expected row
-- counts (323 for Devaraj, matching his real lead count exactly; 348 for
-- management, the full table), confirmed anon access is still fully
-- blocked (0 rows), and confirmed INSERT/UPDATE both work correctly for
-- an executive's own leads while UPDATE on someone else's lead is
-- correctly blocked.
--
-- Applied directly to production on 2026-08-09.
drop policy if exists "authenticated can manage land_leads" on land_leads;

create policy "role-scoped access to land_leads"
  on land_leads for all
  to authenticated
  using (
    public.current_access_role() = 'admin'
    or created_by = auth.uid()
    or (
      public.current_access_role() = 'manager'
      and created_by is not null
      and public.is_in_reporting_line_of(auth.uid(), created_by)
    )
  )
  with check (
    public.current_access_role() = 'admin'
    or created_by = auth.uid()
    or (
      public.current_access_role() = 'manager'
      and created_by is not null
      and public.is_in_reporting_line_of(auth.uid(), created_by)
    )
  );
