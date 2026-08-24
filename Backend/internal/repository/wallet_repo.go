package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type WalletRepository struct {
	db *pgxpool.Pool
}

func NewWalletRepository(db *pgxpool.Pool) *WalletRepository {
	return &WalletRepository{db: db}
}

func (r *WalletRepository) GetOrCreate(ctx context.Context, userID string) (*models.Wallet, error) {
	var w models.Wallet
	err := r.db.QueryRow(ctx, `SELECT id, user_id, balance, updated_at FROM wallets WHERE user_id = $1`, userID).
		Scan(&w.ID, &w.UserID, &w.Balance, &w.UpdatedAt)
	if err == nil {
		return &w, nil
	}
	if err != pgx.ErrNoRows {
		return nil, err
	}
	err = r.db.QueryRow(ctx, `INSERT INTO wallets (user_id, balance) VALUES ($1, 0) RETURNING id, user_id, balance, updated_at`,
		userID).Scan(&w.ID, &w.UserID, &w.Balance, &w.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &w, nil
}

// Credit and Debit run inside a transaction so balance updates and the ledger entry are atomic.
func (r *WalletRepository) Credit(ctx context.Context, userID string, amount float64, reason string, refID *string) (*models.Wallet, error) {
	return r.adjust(ctx, userID, amount, "credit", reason, refID)
}

func (r *WalletRepository) Debit(ctx context.Context, userID string, amount float64, reason string, refID *string) (*models.Wallet, error) {
	return r.adjust(ctx, userID, -amount, "debit", reason, refID)
}

func (r *WalletRepository) adjust(ctx context.Context, userID string, delta float64, txType, reason string, refID *string) (*models.Wallet, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var w models.Wallet
	err = tx.QueryRow(ctx, `SELECT id, user_id, balance FROM wallets WHERE user_id = $1 FOR UPDATE`, userID).
		Scan(&w.ID, &w.UserID, &w.Balance)
	if err == pgx.ErrNoRows {
		err = tx.QueryRow(ctx, `INSERT INTO wallets (user_id, balance) VALUES ($1,0) RETURNING id, user_id, balance`, userID).
			Scan(&w.ID, &w.UserID, &w.Balance)
	}
	if err != nil {
		return nil, err
	}

	newBalance := w.Balance + delta
	if newBalance < 0 {
		return nil, errors.New("insufficient wallet balance")
	}

	err = tx.QueryRow(ctx, `UPDATE wallets SET balance = $1, updated_at = now() WHERE id = $2 RETURNING balance, updated_at`,
		newBalance, w.ID).Scan(&w.Balance, &w.UpdatedAt)
	if err != nil {
		return nil, err
	}

	absAmount := delta
	if absAmount < 0 {
		absAmount = -absAmount
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO wallet_transactions (wallet_id, type, amount, reason, reference_id) VALUES ($1,$2,$3,$4,$5)
	`, w.ID, txType, absAmount, reason, refID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &w, nil
}

func (r *WalletRepository) History(ctx context.Context, walletID string) ([]models.WalletTransaction, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, wallet_id, type, amount, COALESCE(reason,''), reference_id, created_at
		FROM wallet_transactions WHERE wallet_id = $1 ORDER BY created_at DESC
	`, walletID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.WalletTransaction
	for rows.Next() {
		var t models.WalletTransaction
		if err := rows.Scan(&t.ID, &t.WalletID, &t.Type, &t.Amount, &t.Reason, &t.ReferenceID, &t.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, nil
}
