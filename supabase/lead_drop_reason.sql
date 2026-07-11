-- Run in Supabase SQL Editor (safe to re-run).
-- Stores why a lead was marked as dropped.

ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS drop_reason TEXT NOT NULL DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS drop_notes TEXT NOT NULL DEFAULT '';
