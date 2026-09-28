-- COD commission "dues" ledger — replaces the wallet-balance gate for cash jobs.
-- A due is created when the technician confirms cash received; it is cleared
-- when the technician pays it via Razorpay (due_settlements).
CREATE TABLE IF NOT EXISTS technician_dues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    technician_user_id UUID NOT NULL REFERENCES users(id),
    payment_id UUID NOT NULL UNIQUE REFERENCES payments(id),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_technician_dues_user_status ON technician_dues(technician_user_id, status);

CREATE TABLE IF NOT EXISTS due_settlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    technician_user_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC(12,2) NOT NULL,
    due_ids UUID[] NOT NULL,
    razorpay_order_id TEXT NOT NULL UNIQUE,
    razorpay_payment_id TEXT,
    status VARCHAR(10) NOT NULL DEFAULT 'created',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at TIMESTAMPTZ
);