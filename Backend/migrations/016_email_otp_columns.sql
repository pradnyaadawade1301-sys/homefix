-- Email OTP (RequestEmailOTP/VerifyEmailOTP) used to reuse the same
-- otp_code/otp_expires_at columns as phone OTP (see 012_email_verification.sql).
-- That meant requesting an email OTP silently invalidated any pending phone
-- OTP for the same user, and vice versa. Give email verification its own
-- columns so the two flows can't stomp on each other.
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_otp_code VARCHAR(10);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_otp_expires_at TIMESTAMPTZ;