-- Reason a technician gives when declining a "Schedule for later" slot (or,
-- via the same column, an instant request) so the customer sees WHY instead
-- of just a generic "declined" status.
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS decline_reason TEXT;