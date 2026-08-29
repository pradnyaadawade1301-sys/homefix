package service

import (
	"errors"

	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type DisputeService struct {
	disputeRepo    *repository.DisputeRepository
	bookingRepo    *repository.BookingRepository
	razorpayService *RazorpayService
	paymentRepo    *repository.PaymentRepository
}

func NewDisputeService(disputeRepo *repository.DisputeRepository, bookingRepo *repository.BookingRepository, razorpayService *RazorpayService, paymentRepo *repository.PaymentRepository) *DisputeService {
	return &DisputeService{disputeRepo: disputeRepo, bookingRepo: bookingRepo, razorpayService: razorpayService, paymentRepo: paymentRepo}
}

// Raise — a customer or technician opens a dispute against a booking/consultation.
func (s *DisputeService) Raise(ctx context.Context, bookingID, consultationID *string, raisedBy, reason string) (*models.Dispute, error) {
	if (bookingID == nil) == (consultationID == nil) {
		return nil, errors.New("exactly one of booking_id or consultation_id is required")
	}
	return s.disputeRepo.Create(ctx, &models.Dispute{BookingID: bookingID, ConsultationID: consultationID, RaisedBy: raisedBy, Reason: reason})
}

func (s *DisputeService) AddEvidence(ctx context.Context, disputeID, uploadedBy, fileURL, note string) (*models.DisputeEvidence, error) {
	return s.disputeRepo.AddEvidence(ctx, &models.DisputeEvidence{DisputeID: disputeID, UploadedBy: uploadedBy, FileURL: fileURL, Note: note})
}

func (s *DisputeService) Get(ctx context.Context, id string) (*models.Dispute, []models.DisputeEvidence, error) {
	d, err := s.disputeRepo.GetByID(ctx, id)
	if err != nil || d == nil {
		return d, nil, err
	}
	evidence, err := s.disputeRepo.ListEvidence(ctx, id)
	return d, evidence, err
}

func (s *DisputeService) ListForUser(ctx context.Context, userID string) ([]models.Dispute, error) {
	return s.disputeRepo.ListByUser(ctx, userID)
}

// ListAll + workflow below are admin-only (see internal/admin).

func (s *DisputeService) ListAll(ctx context.Context, status string) ([]models.Dispute, error) {
	return s.disputeRepo.ListAll(ctx, status)
}

func (s *DisputeService) MarkUnderReview(ctx context.Context, id string) error {
	return s.disputeRepo.SetUnderReview(ctx, id)
}

// Resolve is the admin's decision. When status is resolved_refund or
// resolved_partial, it also actually processes the refund (via UpiService.Refund)
// against the dispute's booking payment — a dispute can't be marked "refunded"
// without the wallet/booking state actually reflecting it.
func (s *DisputeService) Resolve(ctx context.Context, id, status, adminNotes, resolvedBy string, refundAmount *float64) (*models.Dispute, error) {
	d, err := s.disputeRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if d == nil {
		return nil, errors.New("dispute not found")
	}

	if status == models.DisputeResolvedRefund || status == models.DisputeResolvedPartial {
		if d.BookingID == nil {
			return nil, errors.New("refund resolution requires a booking-linked dispute")
		}
		// Look up the payment by booking ID directly, not by the disputing
		// user's own payment list — RaisedBy can be the technician, whose
		// payments have nothing to do with this booking's customer payment.
		payment, err := s.paymentRepo.GetByBookingID(ctx, *d.BookingID)
		if err != nil {
			return nil, err
		}
		if payment == nil || payment.Status != models.PaymentPaid {
			return nil, errors.New("no paid payment found for this booking to refund")
		}
		paymentID := payment.ID
		if _, err := s.razorpayService.Refund(ctx, paymentID); err != nil {
			return nil, err
		}
	}

	if err := s.disputeRepo.Resolve(ctx, id, status, adminNotes, resolvedBy, refundAmount); err != nil {
		return nil, err
	}
	return s.disputeRepo.GetByID(ctx, id)
}

func (s *DisputeService) CountOpen(ctx context.Context) (int, error) {
	return s.disputeRepo.CountOpen(ctx)
}