-- 1. Create app_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on app_settings
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists and create new one
DROP POLICY IF EXISTS "Admins can manage settings" ON public.app_settings;
CREATE POLICY "Admins can manage settings" ON public.app_settings
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid() AND user_roles.role = 'admin'
    )
  );

-- 2. Create the function to send email when pending_changes are inserted
CREATE OR REPLACE FUNCTION public.fn_send_request_email()
RETURNS TRIGGER AS $$
DECLARE
  v_resend_key TEXT;
  v_admin_email TEXT;
  v_sender_email TEXT;
  v_response_id TEXT;
  v_email_body TEXT;
  v_subject TEXT;
  v_type_label TEXT;
  
  -- Accommodation details
  v_staff_id UUID;
  v_bed_code TEXT;
  v_room_number TEXT;
  v_location_name TEXT;
BEGIN
  -- Fetch Resend API Key, Admin Email, and Sender Email from app_settings
  SELECT value INTO v_resend_key FROM public.app_settings WHERE key = 'resend_api_key';
  SELECT value INTO v_admin_email FROM public.app_settings WHERE key = 'admin_email';
  SELECT value INTO v_sender_email FROM public.app_settings WHERE key = 'sender_email';

  -- If API key is not configured, skip email sending
  IF v_resend_key IS NULL OR v_resend_key = '' THEN
    RETURN NEW;
  END IF;

  -- Fallbacks if settings are not set
  IF v_admin_email IS NULL OR v_admin_email = '' THEN
    v_admin_email := 'sgsit2024@gmail.com';
  END IF;
  IF v_sender_email IS NULL OR v_sender_email = '' THEN
    v_sender_email := 'Staff App <onboarding@resend.dev>';
  END IF;

  -- Fetch staff member's assigned accommodation details from DB
  SELECT s.id INTO v_staff_id 
  FROM public.staff s 
  WHERE s.auth_user_id = NEW.submitted_by 
  LIMIT 1;

  IF v_staff_id IS NOT NULL THEN
    SELECT b.bed_code, r.room_number, l.name
    INTO v_bed_code, v_room_number, v_location_name
    FROM public.bed_assignments ba
    JOIN public.beds b ON b.id = ba.bed_id
    JOIN public.rooms r ON r.id = b.room_id
    JOIN public.locations l ON l.id = r.location_id
    WHERE ba.staff_id = v_staff_id
    LIMIT 1;
  END IF;

  -- Set subject and body based on change type
  IF NEW.change_type = 'leave_request' THEN
    v_type_label := 'Leave Request';
    v_subject := 'New Leave Request from ' || COALESCE(NEW.staff_name, 'Staff Member');
    v_email_body := '<div style="font-family: sans-serif; padding: 20px; background-color: #121824; color: #ffffff; border-radius: 12px; border: 1px solid #1f2a40;">' ||
                    '<h2 style="color: #6366f1; margin-top: 0;">New Leave Request</h2>' ||
                    '<p><strong>Staff Name:</strong> ' || COALESCE(NEW.staff_name, 'Unknown') || '</p>' ||
                    '<p><strong>Location:</strong> ' || COALESCE(v_location_name, 'Not Assigned') || '</p>' ||
                    '<p><strong>Room ID:</strong> ' || COALESCE(v_room_number, 'Not Assigned') || '</p>' ||
                    '<p><strong>Bed ID:</strong> ' || COALESCE(v_bed_code, 'Not Assigned') || '</p>' ||
                    '<p><strong>Leave Type:</strong> ' || COALESCE(NEW.payload->>'leave_type', 'Annual') || '</p>' ||
                    '<p><strong>Start Date:</strong> ' || COALESCE(NEW.payload->>'from_date', 'N/A') || '</p>' ||
                    '<p><strong>End Date:</strong> ' || COALESCE(NEW.payload->>'to_date', 'N/A') || '</p>' ||
                    '<p><strong>Reason:</strong> ' || COALESCE(NEW.payload->>'reason', 'N/A') || '</p>' ||
                    '<hr style="border: 0; border-top: 1px solid #1f2a40; margin: 20px 0;">' ||
                    '<p style="font-size: 12px; color: #8a99ad;">Please log in to the Staff Accommodation Dashboard to approve or reject this request.</p>' ||
                    '</div>';
  ELSIF NEW.change_type = 'shift_request' THEN
    v_type_label := 'Room Shift Request';
    v_subject := 'New Room Shift Request from ' || COALESCE(NEW.staff_name, 'Staff Member');
    v_email_body := '<div style="font-family: sans-serif; padding: 20px; background-color: #121824; color: #ffffff; border-radius: 12px; border: 1px solid #1f2a40;">' ||
                    '<h2 style="color: #6366f1; margin-top: 0;">New Room Shift Request</h2>' ||
                    '<p><strong>Staff Name:</strong> ' || COALESCE(NEW.staff_name, 'Unknown') || '</p>' ||
                    '<p><strong>Current Location:</strong> ' || COALESCE(v_location_name, 'Not Assigned') || '</p>' ||
                    '<p><strong>Current Room ID:</strong> ' || COALESCE(v_room_number, 'Not Assigned') || '</p>' ||
                    '<p><strong>Current Bed ID:</strong> ' || COALESCE(v_bed_code, 'Not Assigned') || '</p>' ||
                    '<p><strong>Requested Room ID:</strong> ' || COALESCE(NEW.payload->>'room_id', 'N/A') || '</p>' ||
                    '<p><strong>Reason:</strong> ' || COALESCE(NEW.payload->>'reason', 'N/A') || '</p>' ||
                    '<hr style="border: 0; border-top: 1px solid #1f2a40; margin: 20px 0;">' ||
                    '<p style="font-size: 12px; color: #8a99ad;">Please log in to the Staff Accommodation Dashboard to approve or reject this request.</p>' ||
                    '</div>';
  ELSE
    v_type_label := NEW.change_type;
    v_subject := 'New Request: ' || v_type_label;
    v_email_body := '<div style="font-family: sans-serif; padding: 20px; background-color: #121824; color: #ffffff; border-radius: 12px; border: 1px solid #1f2a40;">' ||
                    '<h2 style="color: #6366f1; margin-top: 0;">New Request</h2>' ||
                    '<p>A new <strong>' || v_type_label || '</strong> has been submitted by <strong>' || COALESCE(NEW.staff_name, 'Unknown') || '</strong>.</p>' ||
                    '<p><strong>Location:</strong> ' || COALESCE(v_location_name, 'Not Assigned') || '</p>' ||
                    '<p><strong>Room ID:</strong> ' || COALESCE(v_room_number, 'Not Assigned') || '</p>' ||
                    '<p><strong>Bed ID:</strong> ' || COALESCE(v_bed_code, 'Not Assigned') || '</p>' ||
                    '</div>';
  END IF;

  -- Perform asynchronous HTTP request using pg_net extension
  SELECT net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_resend_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', v_sender_email,
      'to', jsonb_build_array(v_admin_email),
      'subject', v_subject,
      'html', v_email_body
    )
  )::text INTO v_response_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create Trigger
DROP TRIGGER IF EXISTS tr_send_request_email ON public.pending_changes;
CREATE TRIGGER tr_send_request_email
  AFTER INSERT ON public.pending_changes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_send_request_email();
