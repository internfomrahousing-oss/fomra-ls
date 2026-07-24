-- Run in Supabase SQL Editor (safe to re-run).
-- source_contact_name/source_contact_number: name & mobile of the source
-- contact for Landowner, Referral and Internal Team input sources (Broker
-- keeps using the existing broker_name/broker_contact columns).
-- land_type_other: free-text land type entered when land_type = 'other'.

ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS source_contact_name TEXT DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS source_contact_number TEXT DEFAULT '';
ALTER TABLE land_leads ADD COLUMN IF NOT EXISTS land_type_other TEXT DEFAULT '';
