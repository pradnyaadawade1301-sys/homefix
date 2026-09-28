package repository

import (
	"context"
	"crypto/subtle"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// MaxCashOtpAttempts is how many wrong OTP entries a technician gets before
// the payment locks until the customer taps "New OTP".
const MaxCashOtpAttempts = 5

type CashOtpResult int

const (
	CashOtpOK CashOtpResult = iota
	CashOtpWrong
	CashOtpLocked
	CashOtpMissing
)

// CashOtpRepository keeps the Cash-on-Delivery confirmation OTP in its own
// columns on payments (cash_otp, cash_otp_attempts) — deliberately NOT part of
// models.Payment, so the OTP can never leak through any payment JSON the
// technician's app receives.
type CashOtpRepository struct {
	db *pgxpool.Pool
}

func NewCashOtpRepository(db *pgxpool.Pool) *CashOtpRepository {
	return &CashOtpRepository{db: db}
}

// Set stores a fresh OTP and resets the wrong-attempt counter.
func (r *CashOtpRepository) Set(ctx context.Context, paymentID, otp string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE payments SET cash_otp=$2, cash_otp_attempts=0
		WHERE id=$1 AND status='created' AND method='cash'`, paymentID, otp)
	return err
}

// GetForCustomer returns the OTP only to the payment's own customer, and only
// while the cash payment is still unconfirmed. found=false means no such
// pending cash payment for this user; otp=="" means none generated yet.
func (r *CashOtpRepository) GetForCustomer(ctx context.Context, paymentID, userID string) (otp string, found bool, err error) {
	var v *string
	err = r.db.QueryRow(ctx, `
		SELECT cash_otp FROM payments
		WHERE id=$1 AND user_id=$2 AND status='created' AND method='cash'`, paymentID, userID).Scan(&v)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	if v != nil {
		otp = *v
	}
	return otp, true, nil
}

// Verify checks the technician's OTP. A wrong entry counts toward the lock;
// a correct one does not. remaining is how many wrong tries are left.
func (r *CashOtpRepository) Verify(ctx context.Context, paymentID, otp string) (res CashOtpResult, remaining int, err error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return CashOtpMissing, 0, err
	}
	defer tx.Rollback(ctx)

	var stored *string
	var attempts int
	err = tx.QueryRow(ctx, `
		SELECT cash_otp, cash_otp_attempts FROM payments
		WHERE id=$1 AND status='created' FOR UPDATE`, paymentID).Scan(&stored, &attempts)
	if err != nil {
		return CashOtpMissing, 0, err
	}
	if stored == nil || *stored == "" {
		return CashOtpMissing, 0, nil
	}
	if attempts >= MaxCashOtpAttempts {
		return CashOtpLocked, 0, nil
	}
	if subtle.ConstantTimeCompare([]byte(*stored), []byte(otp)) == 1 {
		return CashOtpOK, MaxCashOtpAttempts - attempts, nil
	}
	attempts++
	if _, err := tx.Exec(ctx, `UPDATE payments SET cash_otp_attempts=$2 WHERE id=$1`, paymentID, attempts); err != nil {
		return CashOtpMissing, 0, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CashOtpMissing, 0, err
	}
	if attempts >= MaxCashOtpAttempts {
		return CashOtpLocked, 0, nil
	}
	return CashOtpWrong, MaxCashOtpAttempts - attempts, nil
}
