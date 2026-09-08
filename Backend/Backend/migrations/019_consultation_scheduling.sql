-- Adds slot-based scheduling to consultations. NULL scheduled_at = the existing
-- "Consult Now" instant flow (unchanged). A non-NULL scheduled_at means the
-- customer picked a future date/time; the technician is asked to confirm that
-- slot (not rung immediately), and the backend automatically flips the
-- consultation to 'ringing' when the slot time arrives (see
-- ConsultationService.PromoteDueScheduled, polled from main.go).

ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_consultations_scheduled_due
  ON consultations (scheduled_at)
  WHERE status = 'confirmed';