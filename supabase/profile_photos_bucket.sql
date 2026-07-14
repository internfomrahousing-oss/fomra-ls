-- Run this in your Supabase SQL Editor (safe to re-run).
-- Per-account profile photos live in a public Storage bucket named
-- `profile-photos`. Each account's picture is stored at a deterministic path
-- derived from its email (e.g. employee_fomrahousing_in.jpg), so every
-- employee keeps their own photo. Images are compressed before upload by the app.

-- Create the public bucket if it doesn't exist.
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow the shared company login (anon + authenticated) to read/write photos.
DROP POLICY IF EXISTS "profile photos read" ON storage.objects;
CREATE POLICY "profile photos read"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'profile-photos');

DROP POLICY IF EXISTS "profile photos write" ON storage.objects;
CREATE POLICY "profile photos write"
  ON storage.objects FOR ALL
  TO anon, authenticated
  USING (bucket_id = 'profile-photos')
  WITH CHECK (bucket_id = 'profile-photos');
