-- booking_repo.go's UpsertEstimate / SetEstimateStatus / GetEstimate all
-- read or write booking_estimates.updated_at, but migration 017 never
-- actually added that column (only created_at/decided_at) — this caused
-- "column \"updated_at\" of relation \"booking_estimates\" does not exist"
-- as soon as a technician submitted an estimate. Add it, defaulting existing
-- rows to their created_at so nothing reads as NULL.

ALTER TABLE booking_estimates
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE booking_estimates SET updated_at = created_at WHERE updated_at IS NULL;