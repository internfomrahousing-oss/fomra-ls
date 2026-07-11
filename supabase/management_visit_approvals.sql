-- Run in Supabase SQL Editor (safe to re-run).
-- Management site visit approvals + lead status notifications.
-- Also removes automatic notifications on every new lead insert.

-- Optional link from a notification row to another record (e.g. site visit id).
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS reference_id TEXT;

-- Approval workflow for employee-requested management site visits.
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved';
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS management_notes TEXT NOT NULL DEFAULT '';
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE land_lead_site_visits
  ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT NOT NULL DEFAULT '';

-- Stop notifying management on every new lead upload.
DROP TRIGGER IF EXISTS trg_notify_management_on_new_lead ON land_leads;
DROP FUNCTION IF EXISTS notify_management_on_new_lead();

-- Notify management when a lead moves into negotiation or legal.
CREATE OR REPLACE FUNCTION notify_management_on_lead_status()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.status IN ('negotiation', 'legal')
     AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO notifications (audience, type, title, message, lead_id)
    VALUES (
      'management',
      'lead',
      'Lead in ' || INITCAP(NEW.status),
      COALESCE(NULLIF(NEW.owner_name, ''), 'Lead #' || NEW.id)
        || ' moved to ' || NEW.status
        || CASE WHEN COALESCE(NEW.created_by_name, '') <> ''
                THEN ' — by ' || NEW.created_by_name ELSE '' END,
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_management_on_lead_status ON land_leads;

CREATE TRIGGER trg_notify_management_on_lead_status
  AFTER UPDATE OF status ON land_leads
  FOR EACH ROW EXECUTE FUNCTION notify_management_on_lead_status();
