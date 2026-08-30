-- Adds "Continue with Google" sign-in. Google gives us an email + name, not
-- a phone number, so phone can no longer be a hard NOT NULL requirement —
-- existing phone-based signups are completely unaffected (their phone value
-- just stays as it is; this only relaxes the constraint for NEW rows).
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;

-- Stores the stable Google account id ("sub" claim) so a returning Google
-- user is matched even if their email is later reused elsewhere.
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;