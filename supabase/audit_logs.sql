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
  module text default '',
  lead_id text default '',
  owner_name text default '',
  broker_name text default '',
  executive_name text default '',
  timestamp timestamptz not null default now()
);

-- Safe to re-run on a table created before these filter columns existed.
alter table public.audit_logs add column if not exists module text default '';
alter table public.audit_logs add column if not exists lead_id text default '';
alter table public.audit_logs add column if not exists owner_name text default '';
alter table public.audit_logs add column if not exists broker_name text default '';
alter table public.audit_logs add column if not exists executive_name text default '';

create index if not exists audit_logs_timestamp_idx
  on public.audit_logs (timestamp desc);

create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id);

create index if not exists audit_logs_lead_id_idx
  on public.audit_logs (lead_id);

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
