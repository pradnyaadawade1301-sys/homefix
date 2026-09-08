-- Physical Inspection -> Estimate -> Approval flow.
--
-- Previously a technician went straight from `in_progress` to Complete()
-- with a single final_price, with no step for the customer to see or agree
-- to a cost breakdown first. This adds that gate: once on-site, the
-- technician submits a labour+parts estimate; the booking moves to
-- 'awaiting_estimate_approval' and the customer must approve or decline it
-- before work (and the eventual invoice) can proceed. A decline just moves
-- the booking back to 'in_progress' so the technician can revise and
-- resubmit — every attempt is kept as its own row so the negotiation
-- history is never lost.

CREATE TABLE IF NOT EXISTS booking_estimates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES technicians(id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending | approved | declined
    labour_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    parts_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    note TEXT,
    customer_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS booking_estimate_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    estimate_id UUID NOT NULL REFERENCES booking_estimates(id) ON DELETE CASCADE,
    item_type VARCHAR(10) NOT NULL, -- labour | part
    name VARCHAR(200) NOT NULL,
    quantity NUMERIC(10,2) NOT NULL DEFAULT 1,
    unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    amount NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_booking_estimates_booking_id ON booking_estimates(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_estimate_items_estimate_id ON booking_estimate_items(estimate_id);