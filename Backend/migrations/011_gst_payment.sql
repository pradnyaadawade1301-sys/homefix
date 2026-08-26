ALTER TABLE payments
  ADD COLUMN base_amount NUMERIC(10, 2),
  ADD COLUMN gst_amount NUMERIC(10, 2),
  ADD COLUMN gst_percent NUMERIC(5, 2);