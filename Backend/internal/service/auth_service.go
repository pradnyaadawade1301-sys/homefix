package service

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
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

// Logout clears the user's stored FCM token so it no longer receives push
// notifications. Without this, if a different account (customer or
// technician) later logs in on the same physical device without
// reinstalling the app, the FCM token stays the same and this user's old
// row would keep matching that device — so pushes meant for THIS user
// would land on whoever is now logged in there instead.
func (s *AuthService) Logout(ctx context.Context, userID string) error {
	return s.userRepo.SetFCMToken(ctx, userID, "")
}

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

func (s *AuthService) RequestPasswordReset(ctx context.Context, email string) error {
	u, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return err
	}
	if u == nil {
		return errors.New("no account found with this email")
	}

	otp, err := utils.GenerateOTP()
	if err != nil {
		return err
	}
	expiresAt := time.Now().Add(10 * time.Minute)
	if err := s.userRepo.SetEmailOTP(ctx, u.ID, otp, expiresAt); err != nil {
		return err
	}
	if s.mailService != nil {
		go func() {
			if err := s.mailService.SendOTPEmail(email, otp); err != nil {
				log.Printf("warning: async password-reset OTP email send failed for %s: %v", email, err)
			}
		}()
	}
	return nil
}

// ResetPassword verifies the code sent by RequestPasswordReset and, on
// success, sets the new password and invalidates the OTP so it can't be
// reused for a second reset.
func (s *AuthService) ResetPassword(ctx context.Context, email, otp, newPassword string) error {
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

	hash, err := utils.HashPassword(newPassword)
	if err != nil {
		return err
	}
	if err := s.userRepo.SetPasswordHash(ctx, u.ID, hash); err != nil {
		return err
	}
	return s.userRepo.ClearEmailOTP(ctx, u.ID)
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
	// LoginWithGoogle already checks this (see below) — the password path was
	// missing it entirely, letting a deactivated/banned user log in as long
	// as they still knew their password.
	if !u.IsActive {
		return nil, "", "", errors.New("this account has been deactivated")
	}
	access, refresh, err := s.issueTokens(u.ID, u.Role)
	if err != nil {
		return nil, "", "", err
	}
	return u, access, refresh, nil
}

// SignupWithPassword creates a new account (customer or technician) with name/email/phone/password.
// Role is restricted to "customer" or "technician" — admin accounts are never self-service.
// Phone is optional now that the signup screen no longer collects it; if blank, a unique
// internal placeholder is generated since the phone column is still NOT NULL UNIQUE. That
// placeholder is not a real number — anything that dials it (call-technician/call-customer
// buttons) won't work until the person sets a real phone number some other way.
func (s *AuthService) SignupWithPassword(ctx context.Context, name, email, phone, password, role string) (*models.User, string, string, error) {
	if role != "customer" && role != "technician" {
		role = "customer"
	}
	if phone == "" {
		p, err := generatePlaceholderPhone()
		if err != nil {
			return nil, "", "", err
		}
		phone = p
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

// generatePlaceholderPhone produces a unique, obviously-not-real number
// (leading "0", which no real Indian mobile number uses) for accounts
// created without a phone number — see SignupWithPassword.
func generatePlaceholderPhone() (string, error) {
	b := make([]byte, 4)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	n := uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])
	return fmt.Sprintf("0%09d", n%1_000_000_000), nil
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

// ChangePassword is used by the "current password -> new password" flow on the
// Personal Information screen. Unlike SetPassword (OTP flow, no verification),
// this checks the caller's current password before writing the new one.
func (s *AuthService) ChangePassword(ctx context.Context, userID, currentPassword, newPassword string) error {
	u, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if u == nil || u.PasswordHash == "" {
		return errors.New("invalid current password")
	}
	if !utils.CheckPassword(currentPassword, u.PasswordHash) {
		return errors.New("invalid current password")
	}
	hash, err := utils.HashPassword(newPassword)
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
