-- Live chat thread attached to a dispute (complaint), so the customer and
-- the admin/support team can go back and forth instead of only a one-shot
-- reason + resolution.
CREATE TABLE IF NOT EXISTS dispute_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispute_id UUID NOT NULL REFERENCES disputes(id) ON DELETE CASCADE,
    sender_id UUID NULL REFERENCES users(id) ON DELETE SET NULL, -- NULL when sender_role = 'admin'
    sender_role VARCHAR(16) NOT NULL CHECK (sender_role IN ('user', 'admin')),
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dispute_messages_dispute_id ON dispute_messages(dispute_id, created_at);