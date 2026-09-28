-- Cash-on-delivery OTP: when the customer picks "Cash on Delivery" a 4-digit
-- code is generated and shown ONLY in the customer's app. The customer reads
-- it out after handing over the cash; the technician must enter it on
-- "Cash Received" — only the right code marks the payment paid.
ALTER TABLE payments ADD COLUMN IF NOT EXISTS cash_otp VARCHAR(4);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS cash_otp_attempts INT NOT NULL DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS cash_otp_verified_at TIMESTAMPTZ;