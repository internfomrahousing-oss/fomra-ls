-- Run this in the Supabase SQL Editor AFTER device_tokens.sql.
-- Fires an HTTP POST to /api/push whenever a notification is inserted, which
-- sends the FCM push. This replaces the Database → Webhooks UI step by wiring
-- the same call as a trigger (uses the pg_net extension).

-- 1) Enable pg_net (safe to re-run).
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2) Trigger function: POST the new notification row to the push endpoint.
CREATE OR REPLACE FUNCTION notify_push_on_notification()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://fomra-ls.vercel.app/api/push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object(
      'type',   'INSERT',
      'table',  'notifications',
      'record', to_jsonb(NEW)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Attach it to the notifications table.
DROP TRIGGER IF EXISTS trg_push_on_notification ON notifications;

CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION notify_push_on_notification();
