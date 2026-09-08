-- Fixes a gap in 023_booking_warranty.sql: booking_repo.go's detailedSelect
-- and GetByID reference bookings.service_code (a short human-readable code
-- for a booking, shown on warranty-claim bookings so customers can quote
-- the original service), but the column was never created — causing every
-- /bookings/me and /bookings/:id read to fail with a DB error.

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS service_code TEXT NULL;

-- Backfill existing rows with a short code derived from their id, so
-- historical bookings aren't left NULL once this column starts being read.
UPDATE bookings
SET service_code = 'SVC-' || UPPER(SUBSTRING(id::text, 1, 8))
WHERE service_code IS NULL;