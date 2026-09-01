-- Lets a technician send a simple, structured "here's what I found and what
-- it'll cost" recommendation right after a Live Video Consultation ends,
-- instead of the call just hanging up with nothing further. The customer
-- then explicitly Accepts (turns it into a real booking, same technician —
-- see ConsultationService.Escalate) or Declines it (no booking created).
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS recommendation_summary TEXT;
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS recommendation_price NUMERIC(10,2);
-- pending | accepted | declined. NULL = no recommendation sent for this call.
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS recommendation_status VARCHAR(20);
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS recommendation_sent_at TIMESTAMP;