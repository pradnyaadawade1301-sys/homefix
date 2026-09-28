package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type DueRepository struct {
	db *pgxpool.Pool
}

func NewDueRepository(db *pgxpool.Pool) *DueRepository { return &DueRepository{db: db} }

// Create is idempotent per payment (UNIQUE payment_id) — confirming the same
// cash payment twice never creates a second due.
func (r *DueRepository) Create(ctx context.Context, userID, paymentID, bookingID string, amount float64) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO technician_dues (technician_user_id, payment_id, booking_id, amount)
		VALUES ($1,$2,$3,$4) ON CONFLICT (payment_id) DO NOTHING`,
		userID, paymentID, bookingID, amount)
	return err
}

// PendingStats returns the total pending amount and the oldest pending due's time.
func (r *DueRepository) PendingStats(ctx context.Context, userID string) (float64, *time.Time, error) {
	var total float64
	var oldest *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount),0), MIN(created_at)
		FROM technician_dues WHERE technician_user_id=$1 AND status='pending'`, userID).Scan(&total, &oldest)
	return total, oldest, err
}

func (r *DueRepository) List(ctx context.Context, userID string, limit int) ([]models.Due, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, payment_id, booking_id, amount, status, created_at, paid_at
		FROM technician_dues WHERE technician_user_id=$1
		ORDER BY (status='pending') DESC, created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []models.Due{}
	for rows.Next() {
		var d models.Due
		if err := rows.Scan(&d.ID, &d.PaymentID, &d.BookingID, &d.Amount, &d.Status, &d.CreatedAt, &d.PaidAt); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// PendingIDsAndTotal snapshots the pending dues a settlement order will cover.
func (r *DueRepository) PendingIDsAndTotal(ctx context.Context, userID string) ([]string, float64, error) {
	rows, err := r.db.Query(ctx, `SELECT id::text, amount FROM technician_dues WHERE technician_user_id=$1 AND status='pending'`, userID)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	ids := []string{}
	var total float64
	for rows.Next() {
		var id string
		var amt float64
		if err := rows.Scan(&id, &amt); err != nil {
			return nil, 0, err
		}
		ids = append(ids, id)
		total += amt
	}
	return ids, total, rows.Err()
}

func (r *DueRepository) CreateSettlement(ctx context.Context, userID, orderID string, amount float64, dueIDs []string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO due_settlements (technician_user_id, amount, due_ids, razorpay_order_id)
		VALUES ($1,$2,$3::uuid[],$4)`, userID, amount, dueIDs, orderID)
	return err
}

// MarkSettlementPaid clears the dues covered by the order. Idempotent: a repeat
// call for an already-paid settlement is a no-op.
func (r *DueRepository) MarkSettlementPaid(ctx context.Context, userID, orderID, paymentID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var settlementID, status string
	var dueIDs []string
	err = tx.QueryRow(ctx, `
		SELECT id::text, status, due_ids::text[] FROM due_settlements
		WHERE razorpay_order_id=$1 AND technician_user_id=$2 FOR UPDATE`, orderID, userID).
		Scan(&settlementID, &status, &dueIDs)
	if errors.Is(err, pgx.ErrNoRows) {
		return errors.New("settlement order not found")
	}
	if err != nil {
		return err
	}
	if status == "paid" {
		return nil
	}
	if _, err := tx.Exec(ctx, `
		UPDATE technician_dues SET status='paid', paid_at=now()
		WHERE id = ANY($1::uuid[]) AND status='pending'`, dueIDs); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE due_settlements SET status='paid', razorpay_payment_id=$2, paid_at=now() WHERE id=$1::uuid`,
		settlementID, paymentID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
