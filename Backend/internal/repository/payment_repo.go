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
	       amount, base_amount, gst_amount, gst_percent, currency, method, status, upi_status, upi_response_code, upi_approval_ref,
	       verified, platform_commission, technician_earning, refunded_at, created_at, updated_at`

func scanPayment(row pgx.Row) (*models.Payment, error) {
	var p models.Payment
	err := row.Scan(&p.ID, &p.BookingID, &p.UserID, &p.TransactionRef, &p.UpiTxnID, &p.InvoiceNumber,
		&p.Amount, &p.BaseAmount, &p.GstAmount, &p.GstPercent, &p.Currency, &p.Method, &p.Status, &p.UpiStatus, &p.UpiResponseCode, &p.UpiApprovalRef,
		&p.Verified, &p.PlatformCommission, &p.TechnicianEarning, &p.RefundedAt, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *PaymentRepository) Create(ctx context.Context, p *models.Payment) (*models.Payment, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO payments (booking_id, user_id, transaction_ref, amount, base_amount, gst_amount, gst_percent, currency, status)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'created')
		RETURNING id, status, created_at, updated_at
	`, p.BookingID, p.UserID, p.TransactionRef, p.Amount, p.BaseAmount, p.GstAmount, p.GstPercent, p.Currency).Scan(&p.ID, &p.Status, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return p, nil
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
