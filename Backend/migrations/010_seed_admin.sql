-- Seeds the very first admin account so the hidden /admin panel is reachable on a
-- fresh deploy (there is no public signup path for role='admin' — see
-- auth_handler.go's Signup, which only ever creates customer/technician).
--
-- IMPORTANT: change this password immediately after first login (Users ->
-- deactivate this account and create a new admin, or update it directly in the
-- database) — it is a well-known default, not a secret.
--   Login:    admin@homefixlive.local
--   Password: ChangeMe123!

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (phone, name, email, password_hash, role, phone_verified, is_active)
VALUES (
    '9999999999',
    'Default Admin',
    'admin@homefixlive.local',
    crypt('ChangeMe123!', gen_salt('bf')), -- bcrypt, same format golang.org/x/crypto/bcrypt verifies
    'admin',
    true,
    true
)
ON CONFLICT (email) DO NOTHING;
