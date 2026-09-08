-- Seeds one 'finance' role user for the new React Finance Panel.
-- Password must be set via the app's normal set-password flow, OR update
-- password_hash below with a bcrypt hash before running (same pattern as
-- 010_seed_admin.sql). Role 'finance' is just a new string value — no schema
-- change needed since users.role is already a free-form varchar.

INSERT INTO users (name, email, phone, role, password_hash, phone_verified, email_verified, is_active)
VALUES (
  'Finance Admin',
  'finance@homefixlive.com',
  '9999999998',
  'finance',
  '$2a$10$REPLACE_WITH_REAL_BCRYPT_HASH',
  true,
  true,
  true
)
ON CONFLICT (email) DO NOTHING;