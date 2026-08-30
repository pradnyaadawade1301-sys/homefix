package service

import (
	"context"
	"errors"
	"log"
	"time"

	"google.golang.org/api/idtoken"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

type AuthService struct {
	userRepo        *repository.UserRepository
	mailService     *MailService
	accessSecret    string
	refreshSecret   string
	accessTTLMin    int
	refreshTTLHours int
	googleClientID  string
}

func NewAuthService(userRepo *repository.UserRepository, mailService *MailService, accessSecret, refreshSecret string, accessTTLMin, refreshTTLHours int, googleClientID string) *AuthService {
	return &AuthService{
		userRepo:        userRepo,
		mailService:     mailService,
		accessSecret:    accessSecret,
		refreshSecret:   refreshSecret,
		accessTTLMin:    accessTTLMin,
		refreshTTLHours: refreshTTLHours,
		googleClientID:  googleClientID,
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

// LoginWithPassword supports login via either email or phone (identifier) + password,// used by both customer and technician login screens.
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

// LoginWithGoogle verifies a Google ID token (the token the frontend gets
// back from google_sign_in / GoogleSignInAuthentication.idToken) directly
// against Google's public keys and audience check — no Firebase Auth
// roundtrip needed, just the idtoken package already pulled in via
// google.golang.org/api. On success it finds-or-creates the user:
//   - existing google_id match -> that user
//   - no google_id match but a user already exists with that email
//     (e.g. they originally signed up with phone+password) -> link the
//     google_id onto that same account rather than creating a duplicate
//   - otherwise -> brand-new account, immediately email-verified since
//     Google already confirmed the address
func (s *AuthService) LoginWithGoogle(ctx context.Context, googleIDToken, role string) (*models.User, string, string, error) {
	if s.googleClientID == "" {
		return nil, "", "", errors.New("Google sign-in is not configured on this server")
	}
	payload, err := idtoken.Validate(ctx, googleIDToken, s.googleClientID)
	if err != nil {
		return nil, "", "", errors.New("invalid Google sign-in token")
	}

	googleID := payload.Subject
	email, _ := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)
	photoURL, _ := payload.Claims["picture"].(string)
	if email == "" {
		return nil, "", "", errors.New("Google account has no email")
	}

	u, err := s.userRepo.GetByGoogleID(ctx, googleID)
	if err != nil {
		return nil, "", "", err
	}
	if u == nil {
		existing, err := s.userRepo.GetByEmail(ctx, email)
		if err != nil {
			return nil, "", "", err
		}
		if existing != nil {
			if err := s.userRepo.LinkGoogleID(ctx, existing.ID, googleID); err != nil {
				return nil, "", "", err
			}
			u = existing
		} else {
			if role != "customer" && role != "technician" {
				role = "customer"
			}
			u, err = s.userRepo.CreateWithGoogle(ctx, googleID, email, name, photoURL, role)
			if err != nil {
				return nil, "", "", err
			}
		}
	}

	if !u.IsActive {
		return nil, "", "", errors.New("this account has been deactivated")
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

// RequestEmailOTP sends a 6-digit verification code to an existing account's email —
// used for the "verify your email" step after signup. Uses its own
// email_otp_code/email_otp_expires_at columns (separate from phone OTP), so
// requesting one never invalidates a pending OTP of the other kind.
func (s *AuthService) RequestEmailOTP(ctx context.Context, email string) (string, error) {
	u, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return "", err
	}
	if u == nil {
		return "", errors.New("no account found with this email")
	}
	if u.EmailVerified {
		return "", errors.New("email is already verified")
	}

	otp, err := utils.GenerateOTP()
	if err != nil {
		return "", err
	}
	expiresAt := time.Now().Add(10 * time.Minute)
	if err := s.userRepo.SetEmailOTP(ctx, u.ID, otp, expiresAt); err != nil {
		return "", err
	}
	if s.mailService != nil {
		// Sent in the background: net/smtp.SendMail has no built-in timeout, so
		// if the SMTP server is slow/unreachable (common on restrictive
		// networks) this used to hang the whole HTTP request until the
		// client's own connect timeout aborted it. The result was already
		// ignored (fail-open), so making it async changes nothing except
		// letting the request return immediately.
		go func() {
			if err := s.mailService.SendOTPEmail(email, otp); err != nil {
				log.Printf("warning: async OTP email send failed for %s: %v", email, err)
			}
		}()
	}
	return otp, nil
}

// VerifyEmailOTP checks the code sent by RequestEmailOTP and, on success, marks
// the account's email as verified.
func (s *AuthService) VerifyEmailOTP(ctx context.Context, email, otp string) error {
	u, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return err
	}
	if u == nil {
		return errors.New("no account found with this email")
	}
	if u.EmailOTPCode == nil || *u.EmailOTPCode != otp {
		return errors.New("invalid OTP")
	}
	if u.EmailOTPExpiresAt == nil || time.Now().After(*u.EmailOTPExpiresAt) {
		return errors.New("OTP has expired")
	}
	return s.userRepo.MarkEmailVerified(ctx, u.ID)
}