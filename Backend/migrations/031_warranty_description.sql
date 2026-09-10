-- Free-text warranty coverage note.
--
-- * The technician can now optionally describe WHAT the warranty covers
--   (e.g. "Compressor and gas refill only"), alongside the existing
--   warranty_days duration — set at the same time, in BookingService.Complete.
-- * Also removes the old category-level warranty_options whitelist
--   restriction on duration (see BookingService.Complete) — the technician
--   can now type any positive number of days/months/years; only the
--   description column is new here, the duration validation change lives
--   in application code, not the schema.

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS warranty_description TEXT NULL;