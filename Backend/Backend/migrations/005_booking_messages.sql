-- Chat messages between a customer and the technician assigned to their
-- booking. Kept simple (booking-scoped, no separate "conversation" concept)
-- since every booking has exactly one customer and at most one technician.
CREATE TABLE IF NOT EXISTS booking_messages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    sender_id   UUID NOT NULL REFERENCES users(id),
    sender_role VARCHAR(20) NOT NULL, -- 'customer' | 'technician'
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_booking_messages_booking_id ON booking_messages(booking_id, created_at);