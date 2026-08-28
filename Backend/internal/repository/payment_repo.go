package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type PaymentRepository struct {
	db *pgxpool.Pool
}

func NewPaymentRepository(db *pgxpool.Pool) *PaymentRepository {
	return &PaymentRepository{db: db}
}

const paymentColumns = `id, booking_id, user_id, transaction_ref, upi_txn_id, invoice_number,
	       amount, base_amount, gst_amount, gst_percent, cgst_amount, sgst_amount, currency, method, status, upi_status, upi_response_code, upi_approval_ref,
	       verified, is_repeat_customer, repeat_discount_percent, repeat_discount_amount,
	       razorpay_order_id, razorpay_payment_id, razorpay_signature,
	       platform_commission, technician_earning, refunded_at, created_at, updated_at`

func scanPayment(row pgx.Row) (*models.Payment, error) {
	var p models.Payment
	err := row.Scan(&p.ID, &p.BookingID, &p.UserID, &p.TransactionRef, &p.UpiTxnID, &p.InvoiceNumber,
		&p.Amount, &p.BaseAmount, &p.GstAmount, &p.GstPercent, &p.CgstAmount, &p.SgstAmount, &p.Currency, &p.Method, &p.Status, &p.UpiStatus, &p.UpiResponseCode, &p.UpiApprovalRef,
		&p.Verified, &p.IsRepeatCustomer, &p.RepeatDiscountPercent, &p.RepeatDiscountAmount,
		&p.RazorpayOrderID, &p.RazorpayPaymentID, &p.RazorpaySignature,
		&p.PlatformCommission, &p.TechnicianEarning, &p.RefundedAt, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *PaymentRepository) Create(ctx context.Context, p *models.Payment) (*models.Payment, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO payments (booking_id, user_id, transaction_ref, amount, base_amount, gst_amount, gst_percent, currency,
		                       is_repeat_customer, repeat_discount_percent, repeat_discount_amount, razorpay_order_id, status)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'created')
		RETURNING id, status, created_at, updated_at
	`, p.BookingID, p.UserID, p.TransactionRef, p.Amount, p.BaseAmount, p.GstAmount, p.GstPercent, p.Currency,
		p.IsRepeatCustomer, p.RepeatDiscountPercent, p.RepeatDiscountAmount, p.RazorpayOrderID).Scan(&p.ID, &p.Status, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return p, nil
}

// GetByRazorpayOrderID looks up the payment row created for a given Razorpay
// order — used by RazorpayService.VerifyAndCapture / MarkFailed, since the app
// hands back the order_id (not our internal transaction_ref) after Checkout.
func (r *PaymentRepository) GetByRazorpayOrderID(ctx context.Context, orderID string) (*models.Payment, error) {
	p, err := scanPayment(r.db.QueryRow(ctx, `SELECT `+paymentColumns+` FROM payments WHERE razorpay_order_id = $1`, orderID))
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return p, err
}

func (r *PaymentRepository) GetByTransactionRef(ctx context.Context, ref string) (*models.Payment, error) {
	p, err := scanPayment(r.db.QueryRow(ctx, `SELECT `+paymentColumns+` FROM payments WHERE transaction_ref = $1`, ref))
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return p, err
}

func (r *PaymentRepository) GetByID(ctx context.Context, id string) (*models.Payment, error) {
	p, err := scanPayment(r.db.QueryRow(ctx, `SELECT `+paymentColumns+` FROM payments WHERE id = $1`, id))
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return p, err
}

// GetByBookingID returns the most recent payment for a booking (a booking normally
// has at most one, but if a failed attempt was retried, the newest is what matters)
// — used to attach pricing/tier info to a booking on the technician's Service
// History screen.
func (r *PaymentRepository) GetByBookingID(ctx context.Context, bookingID string) (*models.Payment, error) {
	p, err := scanPayment(r.db.QueryRow(ctx, `
		SELECT `+paymentColumns+` FROM payments WHERE booking_id = $1 ORDER BY created_at DESC LIMIT 1
	`, bookingID))
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return p, err
}

// ListByUser powers the customer's Payment History screen.
func (r *PaymentRepository) ListByUser(ctx context.Context, userID string) ([]models.Payment, error) {
	rows, err := r.db.Query(ctx, `SELECT `+paymentColumns+` FROM payments WHERE user_id = $1 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Payment
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

// ListAll powers the admin panel's Payment Monitoring screen. status == "" lists
// every payment regardless of status.
func (r *PaymentRepository) ListAll(ctx context.Context, status string) ([]models.Payment, error) {
	query := `SELECT ` + paymentColumns + ` FROM payments`
	args := []interface{}{}
	if status != "" {
		query += ` WHERE status = $1`
		args = append(args, status)
	}
	query += ` ORDER BY created_at DESC LIMIT 200`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Payment
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

// MarkVerifiedPaid records the UPI app's OWN reported response (status/response
// code/approval ref — not just "the user tapped confirm"), the commission split,
// and moves status to paid. Only called once UpiService has confirmed upi_status ==
// SUCCESS — see that method's doc comment for why this is the most a raw UPI intent
// (no PSP/gateway callback) can honestly verify.
func (r *PaymentRepository) MarkVerifiedPaid(
	ctx context.Context,
	ref, upiTxnID, method, invoiceNumber, upiStatus, upiResponseCode, upiApprovalRef string,
	platformCommission, technicianEarning float64,
) error {
	_, err := r.db.Exec(ctx, `
		UPDATE payments
		SET upi_txn_id = $1, method = $2, invoice_number = $3, status = 'paid',
		    upi_status = $4, upi_response_code = NULLIF($5, ''), upi_approval_ref = NULLIF($6, ''),
		    verified = true, platform_commission = $7, technician_earning = $8, updated_at = now()
		WHERE transaction_ref = $9 AND status = 'created'
	`, upiTxnID, method, invoiceNumber, upiStatus, upiResponseCode, upiApprovalRef,
		platformCommission, technicianEarning, ref)
	return err
}

// MarkVerifiedPaidRazorpay records Razorpay's payment_id + signature (already
// independently re-verified server-side — see RazorpayService.VerifyAndCapture),
// the CGST/SGST split (India intra-state GST is always split 50/50 between the
// two — see 015_invoice_details.sql), the commission split, and moves status to paid.
func (r *PaymentRepository) MarkVerifiedPaidRazorpay(
	ctx context.Context,
	razorpayOrderID, razorpayPaymentID, razorpaySignature, method, invoiceNumber string,
	cgstAmount, sgstAmount, platformCommission, technicianEarning float64,
) error {
	_, err := r.db.Exec(ctx, `
		UPDATE payments
		SET razorpay_payment_id = $1, razorpay_signature = $2, method = $3, invoice_number = $4, status = 'paid',
		    cgst_amount = $5, sgst_amount = $6,
		    verified = true, platform_commission = $7, technician_earning = $8, updated_at = now()
		WHERE razorpay_order_id = $9 AND status = 'created'
	`, razorpayPaymentID, razorpaySignature, method, invoiceNumber, cgstAmount, sgstAmount, platformCommission, technicianEarning, razorpayOrderID)
	return err
}

// MarkFailed also records the UPI app's own (non-success) response for audit —
// e.g. so a dispute can show exactly what the UPI app reported.
func (r *PaymentRepository) MarkFailed(ctx context.Context, ref, upiStatus, upiResponseCode string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE payments
		SET status = 'failed', upi_status = NULLIF($2, ''), upi_response_code = NULLIF($3, ''), updated_at = now()
		WHERE transaction_ref = $1 AND status = 'created'
	`, ref, upiStatus, upiResponseCode)
	return err
}

// GetInvoiceDetail returns everything an invoice needs — payment breakdown,
// booking's service_code, category, customer, technician, and address — in
// one joined query, for GET /payments/:id/invoice. Only a 'paid' payment has
// a real invoice to show (verified + platform_commission/technician_earning
// set), which the handler enforces.
func (r *PaymentRepository) GetInvoiceDetail(ctx context.Context, paymentID string) (*models.InvoiceDetail, error) {
	row := r.db.QueryRow(ctx, `
		SELECT p.id, p.booking_id, p.user_id, p.transaction_ref, p.upi_txn_id, p.invoice_number,
		       p.amount, p.base_amount, p.gst_amount, p.gst_percent, p.cgst_amount, p.sgst_amount, p.currency, p.method, p.status,
		       p.upi_status, p.upi_response_code, p.upi_approval_ref,
		       p.verified, p.is_repeat_customer, p.repeat_discount_percent, p.repeat_discount_amount,
		       p.razorpay_order_id, p.razorpay_payment_id, p.razorpay_signature,
		       p.platform_commission, p.technician_earning, p.refunded_at, p.created_at, p.updated_at,
		       b.service_code, COALESCE(b.problem_description,''),
		       c.name AS category_name,
		       cu.name AS customer_name, cu.phone AS customer_phone,
		       COALESCE(tu.name,''), COALESCE(tu.phone,''),
		       a.line1, COALESCE(a.line2,''), a.city, a.state, a.pincode
		FROM payments p
		JOIN bookings b ON b.id = p.booking_id
		JOIN categories c ON c.id = b.category_id
		JOIN addresses a ON a.id = b.address_id
		JOIN users cu ON cu.id = b.customer_id
		LEFT JOIN technicians t ON t.id = b.technician_id
		LEFT JOIN users tu ON tu.id = t.user_id
		WHERE p.id = $1
	`, paymentID)

	var inv models.InvoiceDetail
	var line1, line2, city, state, pincode string
	err := row.Scan(&inv.Payment.ID, &inv.Payment.BookingID, &inv.Payment.UserID, &inv.Payment.TransactionRef, &inv.Payment.UpiTxnID, &inv.Payment.InvoiceNumber,
		&inv.Payment.Amount, &inv.Payment.BaseAmount, &inv.Payment.GstAmount, &inv.Payment.GstPercent, &inv.Payment.CgstAmount, &inv.Payment.SgstAmount,
		&inv.Payment.Currency, &inv.Payment.Method, &inv.Payment.Status,
		&inv.Payment.UpiStatus, &inv.Payment.UpiResponseCode, &inv.Payment.UpiApprovalRef,
		&inv.Payment.Verified, &inv.Payment.IsRepeatCustomer, &inv.Payment.RepeatDiscountPercent, &inv.Payment.RepeatDiscountAmount,
		&inv.Payment.RazorpayOrderID, &inv.Payment.RazorpayPaymentID, &inv.Payment.RazorpaySignature,
		&inv.Payment.PlatformCommission, &inv.Payment.TechnicianEarning, &inv.Payment.RefundedAt, &inv.Payment.CreatedAt, &inv.Payment.UpdatedAt,
		&inv.ServiceCode, &inv.ProblemDescription,
		&inv.CategoryName,
		&inv.CustomerName, &inv.CustomerPhone,
		&inv.TechnicianName, &inv.TechnicianPhone,
		&line1, &line2, &city, &state, &pincode,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	inv.BookingID = inv.Payment.BookingID
	inv.InvoiceNumber = derefString(inv.Payment.InvoiceNumber)
	inv.PaidAt = inv.Payment.UpdatedAt
	inv.IsRepeatCustomer = inv.Payment.IsRepeatCustomer
	inv.RepeatDiscountPercent = inv.Payment.RepeatDiscountPercent
	inv.RepeatDiscountAmount = inv.Payment.RepeatDiscountAmount

	if inv.Payment.BaseAmount != nil {
		inv.BaseAmount = *inv.Payment.BaseAmount
	}
	if inv.Payment.GstPercent != nil {
		inv.CgstPercent = *inv.Payment.GstPercent / 2
		inv.SgstPercent = *inv.Payment.GstPercent / 2
	}
	if inv.Payment.CgstAmount != nil {
		inv.CgstAmount = *inv.Payment.CgstAmount
	}
	if inv.Payment.SgstAmount != nil {
		inv.SgstAmount = *inv.Payment.SgstAmount
	}
	inv.TotalAmount = inv.Payment.Amount

	addrParts := []string{line1}
	if line2 != "" {
		addrParts = append(addrParts, line2)
	}
	addrParts = append(addrParts, city, state, pincode)
	inv.AddressFormatted = joinNonEmpty(addrParts, ", ")

	return &inv, nil
}

func derefString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func joinNonEmpty(parts []string, sep string) string {
	out := ""
	for _, p := range parts {
		if p == "" {
			continue
		}
		if out != "" {
			out += sep
		}
		out += p
	}
	return out
}

// Refund marks a previously-paid payment refunded (reversing it back to the
// customer's in-app wallet — see UpiService.Refund). Only a 'paid' payment can be
// refunded, and only once.
func (r *PaymentRepository) Refund(ctx context.Context, paymentID string, refundedAt time.Time) error {
	_, err := r.db.Exec(ctx, `
		UPDATE payments SET status = 'refunded', refunded_at = $2, updated_at = now()
		WHERE id = $1 AND status = 'paid'
	`, paymentID, refundedAt)
	return err
}