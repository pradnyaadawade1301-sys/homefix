-- Explicit fee line items on the final service invoice.
--
-- platform_fee_amount : flat convenience fee (default ₹50), shown as its own
--                       line and part of the GST-taxable subtotal.
-- visit_charge_amount : flat on-site visit charge (default ₹100), added to a
--                       booking's FIRST service invoice only.
-- bookings.visit_fee_charged : set true once a booking's visit charge has been
--                       collected, so a return visit on the same booking (or a
--                       warranty-claim booking) is never charged again.

ALTER TABLE payments ADD COLUMN IF NOT EXISTS platform_fee_amount NUMERIC(10,2);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS visit_charge_amount NUMERIC(10,2);

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS visit_fee_charged BOOLEAN NOT NULL DEFAULT false;
