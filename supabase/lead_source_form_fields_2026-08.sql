-- Additional structured fields so field-collected data (owner occupation,
-- number of owners, location rating, etc.) has a real home instead of being
-- folded into free-text notes. General-purpose, not specific to any one
-- executive's data collection sheet — this is why it's not a one-off.
--
-- Applied directly to production on 2026-08-03.
alter table land_leads
  add column if not exists num_owners text,
  add column if not exists owner_occupation text,
  add column if not exists location_rating text
    check (location_rating in ('unknown','poor','average','good') or location_rating is null),
  add column if not exists broker_knows_owner boolean,
  add column if not exists management_met_owner boolean,
  add column if not exists owner_meeting_location text;

comment on column land_leads.num_owners is 'Free text, not strictly numeric — source data includes things like "3 (family - brothers)".';
comment on column land_leads.location_rating is 'Executive''s own subjective rating of the site location.';
comment on column land_leads.broker_knows_owner is 'Whether the broker/mediator has a direct relationship with the landowner.';
comment on column land_leads.management_met_owner is 'Whether Management/Head has personally met the owner for this lead.';
