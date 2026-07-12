-- Immutable audit trail (append-only from the app).
-- Run in Supabase SQL editor. Do not grant UPDATE/DELETE to authenticated clients.

create table if not exists public.audit_logs (
  id text primary key,
  user_id text,
  user_name text,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  field text default '',
  old_value text default '',
  new_value text default '',
  timestamp timestamptz not null default now()
);

create index if not exists audit_logs_timestamp_idx
  on public.audit_logs (timestamp desc);

create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id);

alter table public.audit_logs enable row level security;

-- Allow insert + select; no update/delete policies (immutable).
drop policy if exists "audit_logs_insert" on public.audit_logs;
create policy "audit_logs_insert"
  on public.audit_logs for insert
  to authenticated, anon
  with check (true);

drop policy if exists "audit_logs_select" on public.audit_logs;
create policy "audit_logs_select"
  on public.audit_logs for select
  to authenticated, anon
  using (true);
