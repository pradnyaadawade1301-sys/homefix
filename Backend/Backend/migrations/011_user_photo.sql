-- Adds a profile photo URL for all users (customers, technicians, admins).
-- Populated via POST /api/v1/uploads (multipart) then PUT /api/v1/users/me with the
-- returned url in "photo_url". Technicians already had profile_photo_url on the
-- technicians table for KYC; this column is the general-purpose account avatar
-- shown in the app header and profile screen for every role.
ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url TEXT;