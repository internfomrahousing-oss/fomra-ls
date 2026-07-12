-- Voice note metadata (audio files live in storage bucket land-lead-voice-notes).
-- No speech-to-text — audio only.

insert into storage.buckets (id, name, public)
values ('land-lead-voice-notes', 'land-lead-voice-notes', true)
on conflict (id) do nothing;

create table if not exists public.land_lead_voice_notes (
  id uuid primary key default gen_random_uuid(),
  lead_id text not null,
  file_url text not null,
  duration_ms integer default 0,
  logged_by uuid,
  logged_by_name text default '',
  created_at timestamptz not null default now()
);

create index if not exists land_lead_voice_notes_lead_idx
  on public.land_lead_voice_notes (lead_id);

alter table public.land_lead_voice_notes enable row level security;

drop policy if exists "voice_notes_select" on public.land_lead_voice_notes;
create policy "voice_notes_select"
  on public.land_lead_voice_notes for select
  to authenticated, anon
  using (true);

drop policy if exists "voice_notes_insert" on public.land_lead_voice_notes;
create policy "voice_notes_insert"
  on public.land_lead_voice_notes for insert
  to authenticated, anon
  with check (true);
