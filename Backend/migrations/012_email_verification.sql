-- Email verification for signup. Reuses the existing otp_code/otp_expires_at
-- columns (already used for phone-OTP login) for the email OTP as well — same
-- short-lived, single-use code, just delivered by email instead of SMS and
-- verified against email_verified instead of phone_verified.
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false;