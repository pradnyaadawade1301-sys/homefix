-- Adds Uber-style arrival OTP support: when a technician marks a booking
-- "arrived", a fresh 6-digit code is generated and stored here; the customer
-- reads it out to the technician, who enters it back into the app to confirm
-- the job actually starts on-site.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS otp_code VARCHAR(6);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMP NULL;