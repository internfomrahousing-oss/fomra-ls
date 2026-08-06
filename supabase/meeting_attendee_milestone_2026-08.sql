-- Meeting attendee tracking + auto-derived "landowner meeting completed"
-- milestone (per direct product decision, 2026-08).
--
-- Design: landowner_meeting_completed_at is deliberately a cached timestamp
-- derived from the meeting log itself (does the lead have a meeting where
-- attendee_types includes Land Owner or Agreement Holder) — set
-- automatically by the app the first time such a meeting is logged, not a
-- manually-toggled flag. This is self-maintaining (log the meeting
-- correctly and the milestone takes care of itself) and, unlike a plain
-- boolean, it also tells you *when* the milestone was reached, which
-- unlocks cycle-time reporting later. It survives status changes
-- (dropped/on hold/signed) so a report can answer "of leads where we
-- actually met the owner, what happened to them" regardless of current
-- stage — the report we didn't have a way to build before this.
--
-- Applied directly to production on 2026-08-02.
alter table land_lead_meetings
  add column if not exists attendee_types jsonb not null default '[]'::jsonb,
  add column if not exists management_present boolean not null default false;

comment on column land_lead_meetings.attendee_types is
  'Array of strings: Land Owner, Agreement Holder, Broker, Family/Friend, Legal Representative, Other.';

alter table land_leads
  add column if not exists landowner_meeting_completed_at timestamptz;

comment on column land_leads.landowner_meeting_completed_at is
  'Set automatically the first time a meeting is logged for this lead with
   an attendee_type of Land Owner or Agreement Holder.';
