package service

import (
	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type UserService struct {
	userRepo *repository.UserRepository
}

func NewUserService(userRepo *repository.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

func (s *UserService) GetProfile(ctx context.Context, userID string) (*models.User, error) {
	return s.userRepo.GetByID(ctx, userID)
}

func (s *UserService) UpdateProfile(ctx context.Context, userID, name string, email *string) error {
	return s.userRepo.UpdateProfile(ctx, userID, name, email)
}

func (s *UserService) UpdatePhotoURL(ctx context.Context, userID string, photoURL *string) error {
	return s.userRepo.UpdatePhotoURL(ctx, userID, photoURL)
}

func (s *UserService) RegisterFCMToken(ctx context.Context, userID, token string) error {
	return s.userRepo.SetFCMToken(ctx, userID, token)
}

func (s *UserService) AddAddress(ctx context.Context, a *models.Address) (*models.Address, error) {
	return s.userRepo.CreateAddress(ctx, a)
}

func (s *UserService) ListAddresses(ctx context.Context, userID string) ([]models.Address, error) {
	return s.userRepo.ListAddresses(ctx, userID)
}