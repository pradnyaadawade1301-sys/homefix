-- Before/After service-proof photos.
--
-- Separate from `bookings.images` (which is the customer's initial upload of
-- the problem, set at booking creation) — this is the technician's on-site
-- proof: a "before" shot when they start the job and an "after" shot once
-- it's done, so the customer (and support, in a dispute) can see the actual
-- work. Multiple photos per type are allowed, so this is its own table
-- rather than two columns on bookings.

CREATE TABLE IF NOT EXISTS booking_job_photos (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id    UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES technicians(id),
    photo_type    VARCHAR(10) NOT NULL, -- 'before' | 'after'
    image_url     TEXT NOT NULL,
    caption       TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_booking_job_photos_booking_id ON booking_job_photos(booking_id, photo_type);