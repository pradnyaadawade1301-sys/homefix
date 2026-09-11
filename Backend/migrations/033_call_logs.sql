-- Real call history: one row per audio call attempt (booking calls today;
-- consultation_id is kept nullable so the same table can later record Live
-- Video Consultation call attempts too, without a schema change).
--
-- status values:
--   'ringing'  - call initiated, callee has not joined the room yet
--   'received' - callee joined the room (answered_at set)
--   'missed'   - caller hung up / room closed before the callee ever joined
--   'rejected' - callee explicitly declined before joining (reserved for future use)
--
-- duration_seconds is only set once the call actually ends (both legs
-- observed), so an in-progress call reads as answered_at set, ended_at null.

CREATE TABLE IF NOT EXISTS call_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
    caller_user_id UUID NOT NULL REFERENCES users(id),
    callee_user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'ringing',
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    answered_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT call_logs_has_thread CHECK (booking_id IS NOT NULL OR consultation_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_call_logs_caller ON call_logs(caller_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_callee ON call_logs(callee_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_booking ON call_logs(booking_id);