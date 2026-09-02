-- Technician-controlled warranty system.
--
-- * Warranty is opt-in per booking, set by the technician at job completion
--   (see BookingService.Complete) — never automatic.
-- * The *choice* of how many days is constrained to whatever the category
--   allows (categories.warranty_options), enforced in BookingService.Complete —
--   a technician cannot type an arbitrary/unlimited number of days.
-- * A warranty claim is itself a brand-new booking (reuses the entire
--   existing booking lifecycle — accept/track/complete/pay), just tagged as
--   a claim and linked back to the original service via warranty_claim_of.
--   This is deliberate: no separate claims table/flow to keep in sync with
--   the real booking system, per "integrate into the existing system".

ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS warranty_options INT[] NOT NULL DEFAULT '{7,15,30,90}';

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS warranty_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS warranty_days INT NULL,
    ADD COLUMN IF NOT EXISTS warranty_expires_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS is_warranty_claim BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS warranty_claim_of UUID NULL REFERENCES bookings(id);

CREATE INDEX IF NOT EXISTS idx_bookings_warranty_claim_of
    ON bookings (warranty_claim_of)
    WHERE warranty_claim_of IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bookings_warranty_expires_at
    ON bookings (warranty_expires_at)
    WHERE warranty_enabled = TRUE;