-- Run in Supabase SQL Editor after land_leads.sql
-- Adds site photo URL column + public storage bucket for compressed lead photos.

ALTER TABLE land_leads
  ADD COLUMN IF NOT EXISTS site_photo_url TEXT DEFAULT '';

INSERT INTO storage.buckets (id, name, public)
VALUES ('land-lead-photos', 'land-lead-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "anyone can read land lead photos" ON storage.objects;
DROP POLICY IF EXISTS "anyone can upload land lead photos" ON storage.objects;
DROP POLICY IF EXISTS "anyone can update land lead photos" ON storage.objects;
DROP POLICY IF EXISTS "anyone can delete land lead photos" ON storage.objects;

CREATE POLICY "anyone can read land lead photos"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'land-lead-photos');

CREATE POLICY "anyone can upload land lead photos"
  ON storage.objects FOR INSERT
  TO anon, authenticated
  WITH CHECK (bucket_id = 'land-lead-photos');

CREATE POLICY "anyone can update land lead photos"
  ON storage.objects FOR UPDATE
  TO anon, authenticated
  USING (bucket_id = 'land-lead-photos')
  WITH CHECK (bucket_id = 'land-lead-photos');

CREATE POLICY "anyone can delete land lead photos"
  ON storage.objects FOR DELETE
  TO anon, authenticated
  USING (bucket_id = 'land-lead-photos');
