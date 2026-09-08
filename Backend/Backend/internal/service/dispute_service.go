package service

import (
	"errors"

	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type DisputeService struct {
	disputeRepo     *repository.DisputeRepository
	bookingRepo     *repository.BookingRepository
	consultRepo     *repository.ConsultationRepository
	techRepo        *repository.TechnicianRepository
	razorpayService *RazorpayService
	paymentRepo     *repository.PaymentRepository
}

func NewDisputeService(disputeRepo *repository.DisputeRepository, bookingRepo *repository.BookingRepository, consultRepo *repository.ConsultationRepository, techRepo *repository.TechnicianRepository, razorpayService *RazorpayService, paymentRepo *repository.PaymentRepository) *DisputeService {
	return &DisputeService{disputeRepo: disputeRepo, bookingRepo: bookingRepo, consultRepo: consultRepo, techRepo: techRepo, razorpayService: razorpayService, paymentRepo: paymentRepo}
}

// isPartyTo reports whether userID (a raw JWT user ID — could be a customer
// or a technician's own user account) is actually the customer or the
// assigned technician on the given booking/consultation. Every dispute
// operation below calls this before touching the dispute — without it,
// any authenticated user could raise a dispute against, or read the details
// of (including admin notes and refund amount), a booking that isn't theirs
// just by guessing/incrementing an ID.
func (s *DisputeService) isPartyTo(ctx context.Context, bookingID, consultationID *string, userID string) (bool, error) {
	// A technician's user account and their technicians.id are different
	// values, and Booking/Consultation only store the latter — resolve once,
	// lazily, only if we actually need it below.
	var resolvedTechID string
	var techLookedUp bool
	techIDFor := func() (string, error) {
		if !techLookedUp {
			techLookedUp = true
			tech, err := s.techRepo.GetByUserID(ctx, userID)
			if err != nil {
				return "", err
			}
			if tech != nil {
				resolvedTechID = tech.ID
			}
		}
		return resolvedTechID, nil
	}

	if bookingID != nil {
		b, err := s.bookingRepo.GetByID(ctx, *bookingID)
		if err != nil || b == nil {
			return false, err
		}
		if b.CustomerID == userID {
			return true, nil
		}
		techID, err := techIDFor()
		if err != nil {
			return false, err
		}
		return techID != "" && b.TechnicianID != nil && *b.TechnicianID == techID, nil
	}

	if consultationID != nil {
		c, err := s.consultRepo.GetByID(ctx, *consultationID)
		if err != nil || c == nil {
			return false, err
		}
		if c.CustomerID == userID {
			return true, nil
		}
		techID, err := techIDFor()
		if err != nil {
			return false, err
		}
		return techID != "" && c.TechnicianID != nil && *c.TechnicianID == techID, nil
	}

	return false, nil
}

// Raise — a customer or technician opens a dispute against a booking/consultation.
func (s *DisputeService) Raise(ctx context.Context, bookingID, consultationID *string, raisedBy, reason string) (*models.Dispute, error) {
	if (bookingID == nil) == (consultationID == nil) {
		return nil, errors.New("exactly one of booking_id or consultation_id is required")
	}
	ok, err := s.isPartyTo(ctx, bookingID, consultationID, raisedBy)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, errors.New("this booking/consultation does not belong to you")
	}
	return s.disputeRepo.Create(ctx, &models.Dispute{BookingID: bookingID, ConsultationID: consultationID, RaisedBy: raisedBy, Reason: reason})
}

// AddEvidence lets either party to the underlying booking/consultation attach
// evidence — not just whoever originally raised the dispute, since the other
// side (e.g. the technician responding to a customer's dispute) needs to be
// able to add their own photos/notes too.
func (s *DisputeService) AddEvidence(ctx context.Context, disputeID, uploadedBy, fileURL, note string) (*models.DisputeEvidence, error) {
	d, err := s.disputeRepo.GetByID(ctx, disputeID)
	if err != nil {
		return nil, err
	}
	if d == nil {
		return nil, errors.New("dispute not found")
	}
	ok, err := s.isPartyTo(ctx, d.BookingID, d.ConsultationID, uploadedBy)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, errors.New("this dispute does not belong to you")
	}
	return s.disputeRepo.AddEvidence(ctx, &models.DisputeEvidence{DisputeID: disputeID, UploadedBy: uploadedBy, FileURL: fileURL, Note: note})
}

// Get is the customer/technician-facing detail view — GetForUser enforces
// that requestingUserID is actually a party to the dispute's underlying
// booking/consultation before returning anything (including admin notes and
// refund amount, which shouldn't leak to an unrelated user who merely
// guessed a valid dispute ID). Use the admin-only ListAll/Resolve path
// instead for support/ops access to arbitrary disputes.
func (s *DisputeService) GetForUser(ctx context.Context, id, requestingUserID string) (*models.Dispute, []models.DisputeEvidence, error) {
	d, err := s.disputeRepo.GetByID(ctx, id)
	if err != nil || d == nil {
		return d, nil, err
	}
	ok, err := s.isPartyTo(ctx, d.BookingID, d.ConsultationID, requestingUserID)
	if err != nil {
		return nil, nil, err
	}
	if !ok {
		return nil, nil, errors.New("this dispute does not belong to you")
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
		payments, err := s.paymentRepo.ListByUser(ctx, d.RaisedBy)
		if err != nil {
			return nil, err
		}
		var paymentID string
		for _, p := range payments {
			if p.BookingID == *d.BookingID && p.Status == models.PaymentPaid {
				paymentID = p.ID
				break
			}
		}
		if paymentID == "" {
			return nil, errors.New("no paid payment found for this booking to refund")
		}
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