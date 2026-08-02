# Trial account cleanup — 2026-08-02

Executed directly against production per explicit request. This is a historical
record for traceability, not a re-runnable migration.

## Accounts removed (auth.users + employee_profiles)
- sanjay@fomrahousing.in
- sara@fomrahousing.in
- pooja@fomrahousing.in
- nirmal@fomrahousing.in
- sathappan252525@gmail.com (sathappan)
- sahanaravindran11@gmail.com (sahana)
- sathappanpalaniappan07@gmail.com (priyan)

## Accounts kept
- management@fomrahousing.in (no employee_profiles row — shared portal login, by design)
- vijay@fomrahousing.in
- saurabh@fomrahousing.in

## Data removed
- 8 land_leads (ids 1, 2, 3, 6, 7, 8, 9, 10) created by the removed accounts
- All child records for those 8 leads: notifications, land_lead_meetings,
  lead_call_logs, land_lead_site_visits, land_lead_legal_documents,
  land_lead_signed_requests, land_lead_price_history, lead_follow_ups,
  legal_verifications, field_calendar_events
- audit_logs entries attributed to the removed accounts as actor (26 total),
  regardless of which lead — not limited to the 8 leads above
- device_tokens, monthly_target_submissions, monthly_targets rows attributed
  to the removed accounts

## Known, accepted side effect
Leads #8 and #10 (created by sathappan) had activity logged mostly by the
Management account — 2 calls, 4 site visits, and 2 signed requests. Deleting
these leads removed that Management-logged activity too. Flagged explicitly
before deletion; proceeding anyway was a deliberate decision, not an oversight.

## Not covered
No database backup existed at the time of this deletion (Supabase Free plan,
no automated backups) — this action is irreversible. Backups remain a
separately tracked, still-open item.
