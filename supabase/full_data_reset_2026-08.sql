-- Full business-data reset, applied directly to production on 2026-08-14,
-- per direct instruction: clear everything so Devaraj and Saurabh (and
-- Management) start fresh and learn the app by entering real data
-- themselves going forward, rather than the imported/historical data
-- accumulated during earlier sessions.
--
-- Confirmed explicitly before running: all 3 accounts (management/
-- devaraj/saurabh) were kept — only their data was cleared, not their
-- logins.
--
-- Deliberately NOT touched: auth.users, profiles, employee_profiles,
-- user_access_roles (account/role infrastructure, not business data),
-- and the profile-photos storage bucket (a person's own photo, not a
-- business record).
--
-- Verified after applying: every table below at 0, all 3 accounts and
-- their roles intact, and confirmed via a real simulated session that
-- Devaraj's own RLS-scoped view now correctly shows 0 leads (not an
-- error, not stale cached data).
--
-- (Historical record only — this delete is not re-runnable in the sense
-- of restoring anything; it's a log of what happened.)
do $$
begin
  delete from notifications;
  delete from land_lead_meetings;
  delete from lead_call_logs;
  delete from land_lead_site_visits;
  delete from land_lead_legal_documents;
  delete from land_lead_signed_requests;
  delete from land_lead_price_history;
  delete from lead_follow_ups;
  delete from legal_verifications;
  delete from field_calendar_events;
  delete from audit_logs;
  delete from monthly_target_submissions;
  delete from land_leads;
end $$;
