-- Email OTP columns used by the auth flow; no earlier migration created them.
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_otp_code VARCHAR(6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_otp_expires_at TIMESTAMPTZ;