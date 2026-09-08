-- Live Video Consultation (on-demand, peer-to-peer): a customer requests a technician
-- for their category, the backend picks the nearest available one, and once accepted
-- both sides join a peer-to-peer video call using the SAME signaling relay already
-- built for booking calls (internal/handler/call_handler.go) — a consultation's id
-- doubles as its call-room id (GET /ws/call/:id), so no separate media infrastructure
-- is needed here.
CREATE TABLE IF NOT EXISTS consultations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    technician_id UUID REFERENCES technicians(id),
    category_id UUID NOT NULL REFERENCES categories(id),
    -- searching -> ringing -> accepted -> in_call -> ended
    --                     \-> rejected / no_technician (terminal, no call happened)
    status VARCHAR(20) NOT NULL DEFAULT 'searching',
    fee NUMERIC(10,2) NOT NULL DEFAULT 199,
    duration_seconds INT,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, paid, not_required
    -- Set when the technician couldn't fix it remotely and the customer agreed to a
    -- home visit — links this consultation to the booking created for that visit.
    escalated_booking_id UUID REFERENCES bookings(id),
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_consultations_customer ON consultations(customer_id);
CREATE INDEX IF NOT EXISTS idx_consultations_technician ON consultations(technician_id);
CREATE INDEX IF NOT EXISTS idx_consultations_status ON consultations(status);