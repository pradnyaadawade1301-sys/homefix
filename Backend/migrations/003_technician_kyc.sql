-- Technician KYC fields + explicit admin approval status.
-- is_verified stays as a fast boolean flag (used by existing browse/booking queries),
-- approval_status is the source of truth an admin panel and technician app read to
-- show "pending review" / "approved" / "rejected" plus a reason.

ALTER TABLE technicians
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS government_id_url TEXT,
    ADD COLUMN IF NOT EXISTS profile_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE technicians
    ADD CONSTRAINT chk_technicians_approval_status
    CHECK (approval_status IN ('pending', 'approved', 'rejected'));

CREATE INDEX IF NOT EXISTS idx_technicians_approval_status ON technicians(approval_status);

-- Backfill: any technician already marked is_verified = true under the old boolean-only
-- flow is considered approved, so existing verified technicians don't regress.
UPDATE technicians SET approval_status = 'approved' WHERE is_verified = true;
