-- Repeat-customer pricing tier support.
-- Adds columns to `payments` so each payment records whether the customer had
-- already booked this technician before (first-time vs repeat) and what
-- discount, if any, was applied at checkout.

ALTER TABLE payments ADD COLUMN IF NOT EXISTS is_repeat_customer BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS repeat_discount_percent DOUBLE PRECISION;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS repeat_discount_amount DOUBLE PRECISION;

-- Speeds up the "how many prior bookings does this customer have with this
-- technician" lookup (used both for repeat-customer pricing and the
-- technician's repeat-customer list).
CREATE INDEX IF NOT EXISTS idx_bookings_customer_technician
    ON bookings (customer_id, technician_id);