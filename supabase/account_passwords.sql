-- Per-account (per-email) login passwords, synced across all devices.
--
-- Model:
--   * Every account (each employee's email, plus the management/employee portal
--     emails) starts with the default password 'fomra@2024'.
--   * When someone changes their password, it becomes THAT account's password
--     from then on, on every device (stored here, not in browser storage).
--
-- Security:
--   * Passwords are stored only as bcrypt hashes (pgcrypto crypt/gen_salt).
--   * RLS is on with NO direct policies, so anon/authenticated cannot read the
--     hashes. Access is only through the SECURITY DEFINER functions below.
--   * set_account_password requires the CURRENT password, so a caller with just
--     the public anon key cannot reset an account without knowing it.
--
-- Run this once in the Supabase SQL editor.

create extension if not exists pgcrypto with schema extensions;

create table if not exists account_passwords (
  account       text primary key,          -- normalized login email
  password_hash text not null,
  updated_at    timestamptz not null default now()
);

alter table account_passwords enable row level security;
-- Intentionally no policies: only the SECURITY DEFINER functions may touch it.

-- The built-in default password (matches AuthService.portalPassword).
create or replace function _default_account_password()
returns text language sql immutable as $$ select 'fomra@2024' $$;

-- Returns TRUE/FALSE when a custom password is set for the account, or NULL when
-- none is set (the caller then falls back to the built-in default).
create or replace function verify_account_password(p_account text, p_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  stored text;
begin
  select password_hash into stored
    from account_passwords where account = lower(trim(p_account));
  if stored is null then
    return null;
  end if;
  return stored = crypt(p_password, stored);
end;
$$;

-- Sets a new password for the account, but only when the supplied current
-- password is correct (checked against the stored hash, or the built-in default
-- when none is set yet). Returns TRUE on success, FALSE if current is wrong.
create or replace function set_account_password(p_account text, p_current text, p_new text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  acct   text := lower(trim(p_account));
  stored text;
  ok     boolean;
begin
  select password_hash into stored from account_passwords where account = acct;
  if stored is null then
    ok := (p_current = _default_account_password());
  else
    ok := (stored = crypt(p_current, stored));
  end if;

  if not ok then
    return false;
  end if;

  -- Password policy: min 8 chars, at least one letter and one digit, and the
  -- new password may not be the built-in default (forces users off it).
  if length(trim(p_new)) < 8
     or p_new !~ '[A-Za-z]'
     or p_new !~ '[0-9]' then
    raise exception 'weak_password';
  end if;
  if trim(p_new) = _default_account_password() then
    raise exception 'default_password_not_allowed';
  end if;

  insert into account_passwords(account, password_hash, updated_at)
  values (acct, crypt(p_new, gen_salt('bf')), now())
  on conflict (account) do update
    set password_hash = excluded.password_hash, updated_at = now();
  return true;
end;
$$;

-- TRUE when the account has no custom password yet (still on the built-in
-- default). The app uses this after login to force a password change.
create or replace function account_uses_default_password(p_account text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select not exists (
    select 1 from account_passwords where account = lower(trim(p_account))
  );
$$;

grant execute on function verify_account_password(text, text) to anon, authenticated;
grant execute on function set_account_password(text, text, text) to anon, authenticated;
grant execute on function account_uses_default_password(text) to anon, authenticated;
