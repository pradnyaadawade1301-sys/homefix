-- Let a dispute chat message carry a photo/video attachment instead of (or
-- alongside) text, so a customer/technician can just show what's wrong
-- rather than describe it. Mirrors the pattern already used for booking job
-- photos (018_booking_job_photos.sql) and dispute evidence.
ALTER TABLE dispute_messages
    ADD COLUMN IF NOT EXISTS attachment_url  TEXT NULL,
    ADD COLUMN IF NOT EXISTS attachment_type VARCHAR(16) NULL CHECK (attachment_type IN ('image', 'video'));

-- message was NOT NULL when only text messages existed; an attachment-only
-- message (photo/video, no caption) now needs to leave it empty.
ALTER TABLE dispute_messages ALTER COLUMN message DROP NOT NULL;
ALTER TABLE dispute_messages ALTER COLUMN message SET DEFAULT '';

-- A message must have text, an attachment, or both — never neither.
ALTER TABLE dispute_messages
    ADD CONSTRAINT dispute_messages_has_content
    CHECK (
        (message IS NOT NULL AND length(trim(message)) > 0)
        OR attachment_url IS NOT NULL
    );