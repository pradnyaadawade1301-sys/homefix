-- Replace Razorpay gateway fields with a generic UPI (GPay/PhonePe/Paytm) intent flow.
-- No payment gateway keys needed: the backend hands the app a upi://pay deep link,
-- the app launches it, and the customer confirms completion back in-app.

ALTER TABLE payments DROP COLUMN IF EXISTS razorpay_order_id;
ALTER TABLE payments DROP COLUMN IF EXISTS razorpay_payment_id;
ALTER TABLE payments DROP COLUMN IF EXISTS razorpay_signature;

ALTER TABLE payments ADD COLUMN IF NOT EXISTS transaction_ref VARCHAR(64);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS upi_txn_id VARCHAR(100);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(50);

CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_transaction_ref ON payments(transaction_ref);