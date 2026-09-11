-- Lets the chat list show a WhatsApp-style unread-message count per booking.
-- NULL read_at means unread; ListMessages marks the other side's messages
-- read when the recipient opens that chat thread (see BookingService.ListMessages).
ALTER TABLE booking_messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_booking_messages_unread
    ON booking_messages (booking_id, sender_role)
    WHERE read_at IS NULL;