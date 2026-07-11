-- Run in Supabase SQL Editor (safe to re-run).
-- Stores broker details when input_source is 'broker'.

ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS broker_name TEXT DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS broker_contact TEXT DEFAULT '';
