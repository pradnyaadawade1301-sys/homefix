-- Completes the Live Video Consultation flow end-to-end (P2P WebRTC migration):
-- session analytics on the call itself, the ability for a customer to cancel while
-- still searching, and the ability to rate a consultation that never became a
-- home-visit booking (reviews previously required a booking_id).

ALTER TABLE consultations
    ADD COLUMN IF NOT EXISTS reconnect_count INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS connection_quality VARCHAR(10), -- good | fair | poor, sampled client-side
    ADD COLUMN IF NOT EXISTS rating INT CHECK (rating IS NULL OR (rating BETWEEN 1 AND 5)),
    ADD COLUMN IF NOT EXISTS rating_comment TEXT;

-- A consultation review has no home-visit booking behind it, so reviews.booking_id
-- must become optional and gain a consultation_id counterpart. Exactly one of the two
-- must be set (a review is always about one or the other, never both/neither).
ALTER TABLE reviews
    ALTER COLUMN booking_id DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS consultation_id UUID REFERENCES consultations(id) ON DELETE CASCADE;

ALTER TABLE reviews
    DROP CONSTRAINT IF EXISTS reviews_one_subject_chk;
ALTER TABLE reviews
    ADD CONSTRAINT reviews_one_subject_chk
    CHECK ((booking_id IS NOT NULL)::int + (consultation_id IS NOT NULL)::int = 1);

CREATE INDEX IF NOT EXISTS idx_reviews_consultation ON reviews(consultation_id);
