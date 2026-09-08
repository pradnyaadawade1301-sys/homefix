-- Adds customer-provided notes and reference photo URLs to a booking, so the
-- "Book Technician Visit" flow can capture extra context beyond the AI
-- diagnosis's problem_description (matches the Issue Details screen's
-- title/description/images pattern already used for AI diagnosis sessions).

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}';