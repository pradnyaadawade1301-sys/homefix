-- "Visit Fee" flow: when a Live Video Consultation is escalated into an
-- on-site booking (see ConsultationService.Escalate), the customer must pay
-- a small fixed inspection/visit fee (₹99) BEFORE the technician can be
-- marked "on_the_way" — see BookingService.UpdateStatus. This is separate
-- from the final service payment: once the job is complete, the paid visit
-- fee is credited against the final invoice so the customer is never
-- double-charged (see RazorpayService.CreateOrder).

-- not_required = booking wasn't created via consultation escalation, no visit
--                fee applies (e.g. a normal direct booking).
-- pending       = visit fee is required but not yet paid.
-- paid          = visit fee paid, technician allowed to head out.
-- refunded      = booking was cancelled after the visit fee was paid; it was
--                 refunded back to the customer.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS visit_fee_amount NUMERIC(10,2);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS visit_fee_status VARCHAR(20) NOT NULL DEFAULT 'not_required';

-- service    = the normal final-invoice payment (existing flow, unchanged).
-- visit_fee  = the ₹99 pre-visit inspection payment.
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_type VARCHAR(20) NOT NULL DEFAULT 'service';

-- On the FINAL service payment row only: how much of the total was credited
-- back because the customer had already paid the visit fee separately. Kept
-- here (rather than only computed on the fly) so the invoice can show the
-- deduction as a clear line item.
ALTER TABLE payments ADD COLUMN IF NOT EXISTS visit_fee_credit NUMERIC(10,2);

CREATE INDEX IF NOT EXISTS idx_payments_booking_type ON payments(booking_id, payment_type);