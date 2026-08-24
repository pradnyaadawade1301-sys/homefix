package service

import (
	"context"
	"errors"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type ReviewService struct {
	reviewRepo  *repository.ReviewRepository
	bookingRepo *repository.BookingRepository
}

func NewReviewService(reviewRepo *repository.ReviewRepository, bookingRepo *repository.BookingRepository) *ReviewService {
	return &ReviewService{reviewRepo: reviewRepo, bookingRepo: bookingRepo}
}

func (s *ReviewService) Create(ctx context.Context, customerID, bookingID string, rating int, comment string) (*models.Review, error) {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return nil, err
	}
	if b == nil {
		return nil, errors.New("booking not found")
	}
	if b.CustomerID != customerID {
		return nil, errors.New("only the customer of this booking can leave a review")
	}
	if b.Status != models.BookingCompleted {
		return nil, errors.New("booking must be completed before it can be reviewed")
	}
	if b.TechnicianID == nil {
		return nil, errors.New("booking has no assigned technician")
	}
	r := &models.Review{
		BookingID:    bookingID,
		CustomerID:   customerID,
		TechnicianID: *b.TechnicianID,
		Rating:       rating,
		Comment:      comment,
	}
	return s.reviewRepo.Create(ctx, r)
}
