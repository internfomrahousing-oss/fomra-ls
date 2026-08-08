-- land-lead-legal-docs and profile-photos were both public buckets with
-- anon-readable SELECT policies — anyone with the URL, no login required,
-- could read legal documents and profile photos. land-lead-photos (site
-- photos) is intentionally left as-is; only these two were flagged.
--
-- A public bucket serves files via a URL that bypasses RLS entirely, so
-- narrowing the SELECT policy alone would not have been enough — the
-- bucket itself must also become private.
--
-- Applied directly to production on 2026-08-08.
update storage.buckets set public = false
  where id in ('land-lead-legal-docs', 'profile-photos');

drop policy if exists "anyone can read land lead legal docs" on storage.objects;
create policy "authenticated can read land lead legal docs"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'land-lead-legal-docs');

drop policy if exists "profile photos read" on storage.objects;
create policy "authenticated can read profile photos"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'profile-photos');
