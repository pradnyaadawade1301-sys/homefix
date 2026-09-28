-- audio vs video, so booking chat can show "Missed video call" / "Voice call".
ALTER TABLE call_logs ADD COLUMN IF NOT EXISTS call_type VARCHAR(8) NOT NULL DEFAULT 'audio';