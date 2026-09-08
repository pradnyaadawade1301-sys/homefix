-- Closes the "booking becomes Paid without real verification" gap: a raw UPI
-- deep-link intent has no server-to-server gateway callback, so the only honest
-- verification available is the UPI app's OWN response to the app (returned via
-- startActivityForResult, not just "the user says they paid") — this migration adds
-- the columns needed to record and gate on that response, plus the commission
-- split/settlement bookkeeping for technician earnings.

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) NOT NULL DEFAULT 'pending'; -- pending | paid | refunded

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS upi_status VARCHAR(20),         -- raw status the UPI app itself returned (SUCCESS/FAILURE/SUBMITTED)
    ADD COLUMN IF NOT EXISTS upi_response_code VARCHAR(20),
    ADD COLUMN IF NOT EXISTS upi_approval_ref VARCHAR(100),
    ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT false, -- true only once upi_status = SUCCESS was recorded
    ADD COLUMN IF NOT EXISTS platform_commission NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS technician_earning NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_bookings_payment_status ON bookings(payment_status);
