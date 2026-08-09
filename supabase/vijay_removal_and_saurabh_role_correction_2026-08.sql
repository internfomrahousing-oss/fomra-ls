-- Two direct, explicit instructions, applied and verified on production
-- on 2026-08-09:
--
-- 1. "Remove vijay and all the data related to it. Only Saurabh and
--    Devaraj should be in the system apart from management."
--
--    Removed entirely: 14 leads, 449 notifications, 4 meetings, 6 calls,
--    12 site visits, 3 legal documents, 8 signed requests, 1 follow-up,
--    63+39 audit log entries, 1 monthly target submission, plus the
--    auth.users / profiles / employee_profiles / user_access_roles rows.
--    Verified 0 remaining references everywhere afterward.
--
--    Flagged before deleting, not silently done: Management had
--    personally logged 1 call and 1 site visit on Vijay's leads — those
--    went with the deletion since they only existed as records attached
--    to those specific leads.
--
--    (Historical record only — this delete is not re-runnable; vijay's
--    UUID no longer exists in auth.users.)
--
-- 2. "Admin is management only." — Saurabh had been conservatively
--    defaulted to admin in the original RLS rollout, since his tier
--    wasn't confirmed at the time. Now confirmed and corrected:
--    employee_profiles.designation = 'Executive', reports_to empty
--    (doesn't manage anyone), all 9 of his leads are his own. No
--    regression: verified via a real simulated session afterward that
--    he still sees exactly his 9 leads under the 'executive' tier.
update public.user_access_roles
set role = 'executive',
    notes = 'saurabh@fomrahousing.in — confirmed Executive via employee_profiles.designation. '
             'Admin tier is management@ only, per direct confirmation.',
    updated_at = now()
where user_id = '23a39731-7035-43f2-b868-b61f42b588b2';
