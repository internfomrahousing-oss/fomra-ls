-- Ships the lead-renaming feature's database side for the first time —
-- confirmed the Dart code already existed but was never actually
-- deployed (land_leads was missing these columns entirely).
--
-- Applied directly to production on 2026-08-22.
alter table land_leads
  add column if not exists lead_name text not null default '',
  add column if not exists lead_name_locked boolean not null default false;

-- Fixes a real bug found while verifying the rename-approval flow: the
-- outcome notification (approve/reject) needs the requester's real email
-- to match the notifications RLS policy, not their display name — every
-- other approval flow in the app already does this correctly.
alter table land_lead_rename_requests
  add column if not exists requested_by_email text not null default '';
