-- Revised per direct product decision: On Hold must be a selectable stage
-- in the status dropdown, not a separate flag layered on top of the
-- existing stage. Adds a column to remember which stage to resume into
-- (since the lead's own status column will literally become 'onHold' while
-- paused). The is_on_hold/on_hold_reason/on_hold_since/on_hold_expected_resume
-- columns from the earlier migration (on_hold_status_2026-08.sql) are kept
-- and still used for the reason/dates; is_on_hold becomes informational
-- only going forward (the app derives hold state from status = 'onHold' as
-- the source of truth).
--
-- Applied directly to production on 2026-08-02.
alter table land_leads
  add column if not exists on_hold_previous_status text;
