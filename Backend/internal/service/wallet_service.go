package service

import (
	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type WalletService struct {
	walletRepo *repository.WalletRepository
}

func NewWalletService(walletRepo *repository.WalletRepository) *WalletService {
	return &WalletService{walletRepo: walletRepo}
}

func (s *WalletService) GetBalance(ctx context.Context, userID string) (*models.Wallet, error) {
	return s.walletRepo.GetOrCreate(ctx, userID)
}

func (s *WalletService) Credit(ctx context.Context, userID string, amount float64, reason string, refID *string) (*models.Wallet, error) {
	return s.walletRepo.Credit(ctx, userID, amount, reason, refID)
}

func (s *WalletService) Debit(ctx context.Context, userID string, amount float64, reason string, refID *string) (*models.Wallet, error) {
	return s.walletRepo.Debit(ctx, userID, amount, reason, refID)
}

func (s *WalletService) History(ctx context.Context, userID string) ([]models.WalletTransaction, error) {
	w, err := s.walletRepo.GetOrCreate(ctx, userID)
	if err != nil {
		return nil, err
	}
	return s.walletRepo.History(ctx, w.ID)
}