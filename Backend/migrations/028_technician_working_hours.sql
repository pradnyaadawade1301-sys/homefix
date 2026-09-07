-- Technician self-set weekly working hours.
--
-- Display-only: this does NOT gate technician matching or booking (a customer
-- can still book outside these hours). It just tells customers when the
-- technician normally works, and lets the technician app render a schedule
-- editor next to the existing online/offline toggle.
--
-- Shape: a JSON object keyed by lowercase 3-letter weekday. Each value is
-- either {"open":"HH:MM","close":"HH:MM"} (24-hour wall-clock, app-local /
-- IST) or null when the technician does not work that day.

ALTER TABLE technicians
    ADD COLUMN IF NOT EXISTS working_hours JSONB NOT NULL DEFAULT '{
        "mon": {"open": "09:00", "close": "18:00"},
        "tue": {"open": "09:00", "close": "18:00"},
        "wed": {"open": "09:00", "close": "18:00"},
        "thu": {"open": "09:00", "close": "18:00"},
        "fri": {"open": "09:00", "close": "18:00"},
        "sat": {"open": "09:00", "close": "18:00"},
        "sun": null
    }'::jsonb;
