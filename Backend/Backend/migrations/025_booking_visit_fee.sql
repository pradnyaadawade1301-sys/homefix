-- Fixes another gap: booking_repo.go's detailedSelect, GetByID,
-- SetVisitFeeRequired, and SetVisitFeeStatus all reference
-- bookings.visit_fee_amount / bookings.visit_fee_status (the ₹99 pre-visit
-- inspection fee charged when a consultation escalates into a booking — see
-- ConsultationService.Escalate), but no migration ever created these
-- columns. This broke every read of a booking (GET /bookings/me,
-- GET /bookings/:id), and in turn anything that looks up an escalated
-- booking from a consultation (GET /consultations/mine).

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS visit_fee_amount NUMERIC(10,2) NULL,
    ADD COLUMN IF NOT EXISTS visit_fee_status VARCHAR(20) NULL;