-- Technician self-managed settings: service radius, pricing, payout (bank/UPI)
-- details and certificate URLs. Stored as one JSONB blob per technician.
ALTER TABLE technicians
    ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb;