-- Razorpay integration: the payment flow now goes through Razorpay Checkout
-- instead of a raw upi://pay intent. Adds the three identifiers Razorpay's
-- Checkout SDK returns to the app after a successful payment
-- (razorpay_order_id, razorpay_payment_id, razorpay_signature) — the backend
-- re-verifies these itself (HMAC-SHA256 with the account's key secret) before
-- ever marking a payment paid; see internal/service/razorpay_service.go
-- VerifyAndCapture. The old upi_* columns are left in place (unused going
-- forward) so historical UPI-flow payment rows keep their data intact.

ALTER TABLE payments ADD COLUMN IF NOT EXISTS razorpay_order_id VARCHAR(64);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS razorpay_payment_id VARCHAR(64);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS razorpay_signature VARCHAR(128);

CREATE INDEX IF NOT EXISTS idx_payments_razorpay_order_id ON payments (razorpay_order_id);