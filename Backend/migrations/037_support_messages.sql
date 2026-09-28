-- General "Contact Support" live chat, reachable from the Profile screen —
-- separate from dispute_messages (which is always tied to a specific
-- booking/consultation). This is for "customer seedha organization se baat
-- kare" without needing to first raise a formal dispute against a job.
CREATE TABLE IF NOT EXISTS support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_role VARCHAR(16) NOT NULL CHECK (sender_role IN ('user', 'admin')),
    message TEXT NULL,
    attachment_url TEXT NULL,
    attachment_type VARCHAR(16) NULL CHECK (attachment_type IN ('image', 'video')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT support_messages_has_content
        CHECK ((message IS NOT NULL AND length(trim(message)) > 0) OR attachment_url IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON support_messages(user_id, created_at);