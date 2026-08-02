-- On Hold (Land Sourcing Module Review, Critical Issue #10) — implemented as
-- a flag alongside the existing status rather than a new LeadStatus value,
-- deliberately: LeadStatus is matched by several exhaustive switch
-- statements across the Flutter app (label, color, funnel-stage, priority,
-- follow-up-label, performance-weight — 8 separate switches across 6 files),
-- and a paused lead keeping its real pipeline stage (e.g. "on hold, but
-- still in Legal") is more useful than losing that context by moving it to
-- a generic "on hold" status. This also means zero risk of an exhaustiveness
-- compile error introduced without a working CI to catch it.
--
-- Applied directly to production on 2026-08-02.
alter table land_leads
  add column if not exists is_on_hold boolean not null default false,
  add column if not exists on_hold_reason text default '',
  add column if not exists on_hold_since timestamptz,
  add column if not exists on_hold_expected_resume timestamptz;
