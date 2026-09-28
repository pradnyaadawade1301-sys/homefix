-- Audio vs video, so the booking chat can show "Voice call" / "Video call".
ALTER TABLE call_logs ADD COLUMN IF NOT EXISTS call_type VARCHAR(10) NOT NULL DEFAULT 'audio';