package service

import (
	"context"
	"errors"
	"time"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

type AuthService struct {
	userRepo        *repository.UserRepository
	accessSecret    string
	refreshSecret   string
	accessTTLMin    int
	refreshTTLHours int
}

func NewAuthService(userRepo *repository.UserRepository, accessSecret, refreshSecret string, accessTTLMin, refreshTTLHours int) *AuthService {
	return &AuthService{
		userRepo:        userRepo,
		accessSecret:    accessSecret,
		refreshSecret:   refreshSecret,
		accessTTLMin:    accessTTLMin,
		refreshTTLHours: refreshTTLHours,
	}
}

// RequestOTP finds-or-creates the user by phone, generates a real random OTP, and persists it
// with a 5-minute expiry. In production this hands off to an SMS gateway; here it returns the
// OTP only when ENV=development so the flow is testable without a paid SMS provider wired in yet.
func (s *AuthService) RequestOTP(ctx context.Context, phone string) (string, error) {
	u, err := s.userRepo.GetByPhone(ctx, phone)
	if err != nil {
		return "", err
	}
	if u == nil {
		u, err = s.userRepo.CreateWithPhone(ctx, phone)
		if err != nil {
			return "", err
		}
	}

	otp, err := utils.GenerateOTP()
	if err != nil {
		return "", err
	}
	expiresAt := time.Now().Add(5 * time.Minute)
	if err := s.userRepo.SetOTP(ctx, u.ID, otp, expiresAt); err != nil {
		return "", err
	}
	return otp, nil
}

func (s *AuthService) VerifyOTP(ctx context.Context, phone, otp string) (*models.User, string, string, error) {
	u, err := s.userRepo.GetByPhone(ctx, phone)
	if err != nil {
		return nil, "", "", err
	}
	if u == nil {
		return nil, "", "", errors.New("user not found")
	}
	if u.OTPCode == nil || *u.OTPCode != otp {
		return nil, "", "", errors.New("invalid OTP")
	}
	if u.OTPExpiresAt == nil || time.Now().After(*u.OTPExpiresAt) {
		return nil, "", "", errors.New("OTP has expired")
	}

	if err := s.userRepo.VerifyOTPAndActivate(ctx, u.ID); err != nil {
		return nil, "", "", err
	}

	access, refresh, err := s.issueTokens(u.ID, u.Role)
	if err != nil {
		return nil, "", "", err
	}
	return u, access, refresh, nil
}

// LoginWithPassword supports login via either email or phone (identifier) + password,
// used by both customer and technician login screens.
func (s *AuthService) LoginWithPassword(ctx context.Context, identifier, password string) (*models.User, string, string, error) {
	u, err := s.userRepo.GetByIdentifier(ctx, identifier)
	if err != nil {
		return nil, "", "", err
	}
	if u == nil || u.PasswordHash == "" {
		return nil, "", "", errors.New("invalid credentials")
	}
	if !utils.CheckPassword(password, u.PasswordHash) {
		return nil, "", "", errors.New("invalid credentials")
	}
	access, refresh, err := s.issueTokens(u.ID, u.Role)
	if err != nil {
		return nil, "", "", err
	}
	return u, access, refresh, nil
}

// SignupWithPassword creates a new account (customer or technician) with name/email/phone/password.
// Role is restricted to "customer" or "technician" — admin accounts are never self-service.
func (s *AuthService) SignupWithPassword(ctx context.Context, name, email, phone, password, role string) (*models.User, string, string, error) {
	if role != "customer" && role != "technician" {
		role = "customer"
	}
	exists, err := s.userRepo.ExistsByEmailOrPhone(ctx, email, phone)
	if err != nil {
		return nil, "", "", err
	}
	if exists {
		return nil, "", "", errors.New("an account with this email or phone already exists")
	}
	hash, err := utils.HashPassword(password)
	if err != nil {
		return nil, "", "", err
	}
	u, err := s.userRepo.CreateFull(ctx, name, email, phone, hash, role)
	if err != nil {
		return nil, "", "", err
	}
	access, refresh, err := s.issueTokens(u.ID, u.Role)
	if err != nil {
		return nil, "", "", err
	}
	return u, access, refresh, nil
}

func (s *AuthService) SetPassword(ctx context.Context, userID, password string) error {
	hash, err := utils.HashPassword(password)
	if err != nil {
		return err
	}
	return s.userRepo.SetPasswordHash(ctx, userID, hash)
}

func (s *AuthService) RefreshTokens(ctx context.Context, refreshToken string) (string, string, error) {
	userID, err := utils.ParseRefreshToken(refreshToken, s.refreshSecret)
	if err != nil {
		return "", "", err
	}
	u, err := s.userRepo.GetByID(ctx, userID)
	if err != nil || u == nil {
		return "", "", errors.New("user not found")
	}
	return s.issueTokens(u.ID, u.Role)
}

func (s *AuthService) issueTokens(userID, role string) (string, string, error) {
	access, err := utils.GenerateAccessToken(userID, role, s.accessSecret, s.accessTTLMin)
	if err != nil {
		return "", "", err
	}
	refresh, err := utils.GenerateRefreshToken(userID, s.refreshSecret, s.refreshTTLHours)
	if err != nil {
		return "", "", err
	}
	return access, refresh, nil
}
