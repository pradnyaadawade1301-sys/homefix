package service

import (
	"context"
	"errors"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

// AdminService bundles the cross-entity queries/actions only the hidden admin web
// panel (internal/admin) ever calls — never reachable from the Flutter app's own
// API surface (see router.go: none of these are mounted under /api/v1).
type AdminService struct {
	userRepo    *repository.UserRepository
	techRepo    *repository.TechnicianRepository
	techService *TechnicianService
	bookingRepo *repository.BookingRepository
	paymentRepo *repository.PaymentRepository
}

func NewAdminService(
	userRepo *repository.UserRepository,
	techRepo *repository.TechnicianRepository,
	techService *TechnicianService,
	bookingRepo *repository.BookingRepository,
	paymentRepo *repository.PaymentRepository,
) *AdminService {
	return &AdminService{
		userRepo:    userRepo,
		techRepo:    techRepo,
		techService: techService,
		bookingRepo: bookingRepo,
		paymentRepo: paymentRepo,
	}
}

// Login checks admin credentials directly (email or phone + password) — separate
// from the mobile app's AuthService.Login flow, and only ever succeeds for
// role == "admin". Session issuance (cookie) is handled by the caller (internal/admin).
func (s *AdminService) Login(ctx context.Context, identifier, password string) (*models.User, error) {
	u, err := s.userRepo.GetByIdentifier(ctx, identifier)
	if err != nil {
		return nil, err
	}
	if u == nil || u.PasswordHash == "" || !utils.CheckPassword(password, u.PasswordHash) {
		return nil, errors.New("invalid email/phone or password")
	}
	if u.Role != "admin" {
		return nil, errors.New("this account does not have admin access")
	}
	if !u.IsActive {
		return nil, errors.New("this admin account has been deactivated")
	}
	return u, nil
}

func (s *AdminService) ListUsers(ctx context.Context, role string) ([]models.User, error) {
	return s.userRepo.ListAll(ctx, role)
}

func (s *AdminService) SetUserActive(ctx context.Context, userID string, active bool) error {
	return s.userRepo.SetActive(ctx, userID, active)
}

func (s *AdminService) CreateAdmin(ctx context.Context, name, email, phone, password string) (*models.User, error) {
	hash, err := utils.HashPassword(password)
	if err != nil {
		return nil, err
	}
	return s.userRepo.CreateAdmin(ctx, name, email, phone, hash)
}

func (s *AdminService) ListTechniciansByStatus(ctx context.Context, status string) ([]models.TechnicianWithUser, error) {
	return s.techRepo.ListByApprovalStatus(ctx, status)
}

// ApproveTechnician / RejectTechnician wrap TechnicianService.Verify — kept as
// distinct named methods here so the admin panel's intent is explicit in the
// audit log entry, even though the underlying call is the same.
func (s *AdminService) ApproveTechnician(ctx context.Context, technicianID string) error {
	return s.techService.Verify(ctx, technicianID, "approved", "")
}

func (s *AdminService) RejectTechnician(ctx context.Context, technicianID, reason string) error {
	return s.techService.Verify(ctx, technicianID, "rejected", reason)
}

func (s *AdminService) ListBookings(ctx context.Context, status string) ([]models.BookingDetail, error) {
	return s.bookingRepo.ListAllDetailed(ctx, status)
}

func (s *AdminService) ListPayments(ctx context.Context, status string) ([]models.Payment, error) {
	return s.paymentRepo.ListAll(ctx, status)
}
