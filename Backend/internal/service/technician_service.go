package service

import (
	"context"
	"errors"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type TechnicianService struct {
	techRepo *repository.TechnicianRepository
	catRepo  *repository.CategoryRepository
	revRepo  *repository.ReviewRepository
}

func NewTechnicianService(techRepo *repository.TechnicianRepository, catRepo *repository.CategoryRepository, revRepo *repository.ReviewRepository) *TechnicianService {
	return &TechnicianService{techRepo: techRepo, catRepo: catRepo, revRepo: revRepo}
}

// RegisterTechnician creates the technician KYC profile (category, experience, address,
// government ID, profile photo). The row starts life as approval_status = "pending" and
// only becomes bookable once an admin approves it via Verify.
func (s *TechnicianService) RegisterTechnician(ctx context.Context, userID, categoryID string, experienceYears int, address, governmentIDURL, profilePhotoURL string) (*models.Technician, error) {
	cat, err := s.catRepo.GetByID(ctx, categoryID)
	if err != nil {
		return nil, err
	}
	if cat == nil {
		return nil, errors.New("category not found")
	}
	existing, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, errors.New("technician profile already exists for this user")
	}
	t := &models.Technician{
		UserID:          userID,
		CategoryID:      categoryID,
		ExperienceYears: experienceYears,
		Address:         address,
		GovernmentIDURL: governmentIDURL,
		ProfilePhotoURL: profilePhotoURL,
	}
	created, err := s.techRepo.Create(ctx, t)
	if err != nil {
		return nil, err
	}

	// DEV-ONLY: auto-approve every new technician so local testing doesn't
	// require manually visiting the admin panel each time. REMOVE this block
	// before going to production — real technicians must go through actual
	// KYC document review by an admin via Verify().
	if err := s.techRepo.SetApprovalStatus(ctx, created.ID, "approved", ""); err != nil {
		return nil, err
	}
	created.ApprovalStatus = "approved"
	created.IsVerified = true

	return created, nil
}

func (s *TechnicianService) GetProfile(ctx context.Context, technicianID string) (*models.Technician, error) {
	return s.techRepo.GetByID(ctx, technicianID)
}

func (s *TechnicianService) GetByUser(ctx context.Context, userID string) (*models.Technician, error) {
	return s.techRepo.GetByUserID(ctx, userID)
}

// FindAvailable powers the customer-facing nearby/tracking screen — returns available,
// approved technicians for a category with name + category name already joined in, and
// a distance_km when the caller supplies its own lat/lng.
func (s *TechnicianService) FindAvailable(ctx context.Context, categoryID string, lat, lng *float64) ([]models.TechnicianNearby, error) {
	return s.techRepo.ListAvailableByCategory(ctx, categoryID, lat, lng)
}

func (s *TechnicianService) SetAvailability(ctx context.Context, technicianID string, available bool) error {
	return s.techRepo.SetAvailability(ctx, technicianID, available)
}

func (s *TechnicianService) UpdateLocation(ctx context.Context, technicianID string, lat, lng float64) error {
	return s.techRepo.UpdateLocation(ctx, technicianID, lat, lng)
}

// Verify is the admin approve/reject action. status must be "approved" or "rejected";
// reason is stored (and should be shown to the technician) when rejecting.
func (s *TechnicianService) Verify(ctx context.Context, technicianID, status, reason string) error {
	if status != "approved" && status != "rejected" {
		return errors.New(`status must be "approved" or "rejected"`)
	}
	return s.techRepo.SetApprovalStatus(ctx, technicianID, status, reason)
}

func (s *TechnicianService) Reviews(ctx context.Context, technicianID string) ([]models.Review, error) {
	return s.revRepo.ListByTechnician(ctx, technicianID)
}

// ListPublic returns verified technicians (optionally filtered by category) for the
// public, unauthenticated "browse technicians" screen.
func (s *TechnicianService) ListPublic(ctx context.Context, categoryID string) ([]models.TechnicianPublic, error) {
	return s.techRepo.ListPublic(ctx, categoryID)
}

// GetPublicByID returns a single technician's public profile.
func (s *TechnicianService) GetPublicByID(ctx context.Context, id string) (*models.TechnicianPublic, error) {
	return s.techRepo.GetPublicByID(ctx, id)
}