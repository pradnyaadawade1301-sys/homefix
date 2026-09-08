-- CGST/SGST split (India intra-state GST is always split 50/50 between the two)
-- and a human-readable, unique Service ID per booking for invoices/receipts.

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS cgst_amount NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS sgst_amount NUMERIC(10,2);

-- Backfill: existing paid rows had a single combined gst_amount — split it
-- evenly now so old invoices can also render a CGST/SGST breakdown.
UPDATE payments
SET cgst_amount = ROUND(gst_amount / 2, 2),
    sgst_amount = gst_amount - ROUND(gst_amount / 2, 2)
WHERE gst_amount IS NOT NULL AND cgst_amount IS NULL;

CREATE SEQUENCE IF NOT EXISTS booking_service_seq START 1000;

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS service_code VARCHAR(20);

UPDATE bookings
SET service_code = 'SRV-' || LPAD(nextval('booking_service_seq')::text, 6, '0')
WHERE service_code IS NULL;

ALTER TABLE bookings
    ALTER COLUMN service_code SET DEFAULT ('SRV-' || LPAD(nextval('booking_service_seq')::text, 6, '0'));

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'bookings_service_code_unique'
    ) THEN
        ALTER TABLE bookings ADD CONSTRAINT bookings_service_code_unique UNIQUE (service_code);
    END IF;
END $$;

ALTER TABLE bookings
    ALTER COLUMN service_code SET NOT NULL;