-- Fixes QA Bug #3: the "a Signed/Dropped lead's status can't be changed
-- further" rule lived entirely in Dart (LandLeadService.updateStatus),
-- so a direct database write bypassed it completely.
--
-- Deliberately scoped to only the status column, matching the app's own
-- actual behavior exactly — other fields on a terminal lead (notes, price,
-- etc.) aren't blocked by the app either, so this trigger doesn't
-- introduce a new restriction beyond what already exists.
--
-- Carves out the one legitimate exception found by tracing the code:
-- LandLeadService.reopenDropped() (admin-only, reason-required) always
-- increments reopen_count in the same UPDATE statement as the status
-- change. Any status change away from a terminal state is only allowed
-- when that counter actually goes up — anything else (a direct write, or
-- a future bug that forgets this rule) is rejected at the database level.
--
-- Verified after applying, not assumed: a direct status write on a
-- Dropped lead with no reopen_count change was rejected by the database
-- with the expected error; the same lead updated the way
-- reopenDropped() actually does it (status change + reopen_count
-- incremented in one statement) succeeded; a normal status change on a
-- non-terminal lead was completely unaffected. Test lead reverted to
-- its original state afterward.
--
-- Applied directly to production on 2026-08-09.
create or replace function public.enforce_terminal_lead_status()
returns trigger
language plpgsql
as $$
begin
  if old.status in ('signed', 'dropped')
     and new.status is distinct from old.status
     and coalesce(new.reopen_count, 0) <= coalesce(old.reopen_count, 0) then
    raise exception
      'Lead % is % and its status is locked. Use the reopen flow to change it.',
      old.id, old.status;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_terminal_lead_status on land_leads;
create trigger trg_enforce_terminal_lead_status
  before update on land_leads
  for each row
  execute function public.enforce_terminal_lead_status();
