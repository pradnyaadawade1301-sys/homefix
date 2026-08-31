package service

import (
	"context"
	"errors"
	"time"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type ConsultationService struct {
	consultRepo *repository.ConsultationRepository
	techRepo    *repository.TechnicianRepository
	bookingSvc  *BookingService
	reviewRepo  *repository.ReviewRepository
	fcm         *FirebaseService
}

func NewConsultationService(
	consultRepo *repository.ConsultationRepository,
	techRepo *repository.TechnicianRepository,
	bookingSvc *BookingService,
	reviewRepo *repository.ReviewRepository,
	fcm *FirebaseService,
) *ConsultationService {
	return &ConsultationService{consultRepo: consultRepo, techRepo: techRepo, bookingSvc: bookingSvc, reviewRepo: reviewRepo, fcm: fcm}
}

const defaultConsultationFee = 0.0 // Live Consultation is free, no charge

// Request is "Start Live Consultation". If preferredTechnicianID is set (customer
// tapped a specific technician's profile), the call is rung ONLY to that
// technician - no nearest/category-based search happens. If empty, falls back
// to the old nearest-available-in-category matching.
func (s *ConsultationService) Request(ctx context.Context, customerID, categoryID, preferredTechnicianID string, lat, lng *float64) (*models.ConsultationWithDetails, error) {
	c, err := s.consultRepo.Create(ctx, customerID, categoryID, defaultConsultationFee)
	if err != nil {
		return nil, err
	}

	if preferredTechnicianID != "" {
		tech, err := s.techRepo.GetByID(ctx, preferredTechnicianID)
		if err != nil {
			return nil, err
		}
		if tech == nil || !tech.IsAvailable {
			if err := s.consultRepo.UpdateStatus(ctx, c.ID, "no_technician"); err != nil {
				return nil, err
			}
			return s.consultRepo.GetWithDetails(ctx, c.ID)
		}
		if err := s.consultRepo.AssignTechnician(ctx, c.ID, tech.ID); err != nil {
			return nil, err
		}
		// Notify the preferred technician about the incoming consultation request
		if s.fcm != nil {
			_ = s.fcm.SendToUser(ctx, tech.UserID, "New consultation request",
				"A customer has requested a live video consultation with you.",
				map[string]string{"consultation_id": c.ID, "type": "consultation_request"})
		}
		return s.consultRepo.GetWithDetails(ctx, c.ID)
	}

	// Fallback: old nearest-available-by-category matching
	candidates, err := s.techRepo.ListAvailableByCategory(ctx, categoryID, lat, lng, nil)
	if err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		if err := s.consultRepo.UpdateStatus(ctx, c.ID, "no_technician"); err != nil {
			return nil, err
		}
	} else {
		assignedTech := candidates[0]
		if err := s.consultRepo.AssignTechnician(ctx, c.ID, assignedTech.ID); err != nil {
			return nil, err
		}
		// Notify the technician about the incoming consultation request
		if s.fcm != nil {
			tech, techErr := s.techRepo.GetByID(ctx, assignedTech.ID)
			if techErr == nil && tech != nil {
				_ = s.fcm.SendToUser(ctx, tech.UserID, "New consultation request",
					"A customer is requesting a live video consultation.",
					map[string]string{"consultation_id": c.ID, "type": "consultation_request"})
			}
		}
	}

	return s.consultRepo.GetWithDetails(ctx, c.ID)
}

// Accept is the technician tapping [Accept] on the incoming-request card. Only the
// technician the backend actually rang can accept - this stops a stale/rejected
// notification from hijacking a consultation that's already moved on.
func (s *ConsultationService) Accept(ctx context.Context, consultationID, technicianID string) (*models.ConsultationWithDetails, error) {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return nil, err
	}
	if c == nil {
		return nil, errors.New("consultation not found")
	}
	if c.TechnicianID == nil || *c.TechnicianID != technicianID {
		return nil, errors.New("this consultation was not offered to you")
	}
	if err := s.consultRepo.UpdateStatus(ctx, consultationID, "accepted"); err != nil {
		return nil, err
	}
	// Notify the customer that their consultation request was accepted
	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Consultation accepted",
			"A technician has accepted your live video consultation. Connecting now...",
			map[string]string{"consultation_id": consultationID, "type": "consultation_accepted"})
	}
	return s.consultRepo.GetWithDetails(ctx, consultationID)
}

// Reject is the technician tapping [Reject]. Kept deliberately simple for now: the
// consultation is marked rejected rather than auto-retrying the next-nearest
// technician, so the customer sees a clear "declined" state and can request again
// (avoids silently re-ringing a chain of technicians with no visibility to the user).
func (s *ConsultationService) Reject(ctx context.Context, consultationID, technicianID string) error {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return err
	}
	if c == nil {
		return errors.New("consultation not found")
	}
	if c.TechnicianID == nil || *c.TechnicianID != technicianID {
		return errors.New("this consultation was not offered to you")
	}
	if err := s.consultRepo.UpdateStatus(ctx, consultationID, "rejected"); err != nil {
		return err
	}
	// Notify the customer their call wasn't answered — otherwise, if the app is
	// backgrounded, they're left staring at "Searching..." with no signal at all.
	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Call not answered",
			"The technician couldn't take your live video consultation right now.",
			map[string]string{"consultation_id": consultationID, "type": "consultation_rejected"})
	}
	return nil
}

// AcceptByUser resolves the calling user's own technician profile and accepts the
// consultation on their behalf. The Flutter app's Accept button only knows the
// logged-in user (not their internal technician row id), so that lookup happens
// here server-side instead of trusting a technician_id from the client - this is
// what actually connects the customer and technician on the video call.
func (s *ConsultationService) AcceptByUser(ctx context.Context, consultationID, userID string) (*models.ConsultationWithDetails, error) {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if tech == nil {
		return nil, errors.New("technician profile not found")
	}
	return s.Accept(ctx, consultationID, tech.ID)
}

// RejectByUser is the Reject-button counterpart of AcceptByUser.
func (s *ConsultationService) RejectByUser(ctx context.Context, consultationID, userID string) error {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	if tech == nil {
		return errors.New("technician profile not found")
	}
	return s.Reject(ctx, consultationID, tech.ID)
}

func (s *ConsultationService) Get(ctx context.Context, consultationID string) (*models.ConsultationWithDetails, error) {
	return s.consultRepo.GetWithDetails(ctx, consultationID)
}

// MarkStarted flips status to "in_call" the moment both sides have actually joined
// the WebRTC room (see CallHandler in call_handler.go, which relays the signaling
// for both booking calls and consultation calls the same way).
func (s *ConsultationService) MarkStarted(ctx context.Context, consultationID string) error {
	return s.consultRepo.MarkStarted(ctx, consultationID)
}

// End records how long the call actually ran and marks payment as due (fixed fee for
// now - see Consultation.Fee). Duration is measured server-side from started_at so a
// client can't under-report it.
func (s *ConsultationService) End(ctx context.Context, consultationID string) (*models.ConsultationWithDetails, error) {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return nil, err
	}
	if c == nil {
		return nil, errors.New("consultation not found")
	}
	duration := 0
	if c.StartedAt != nil {
		duration = int(time.Since(*c.StartedAt).Seconds())
	}
	if err := s.consultRepo.MarkEnded(ctx, consultationID, duration); err != nil {
		return nil, err
	}
	return s.consultRepo.GetWithDetails(ctx, consultationID)
}

func (s *ConsultationService) MarkPaid(ctx context.Context, consultationID string) error {
	return s.consultRepo.SetPaymentStatus(ctx, consultationID, "paid")
}

// EndWithStats is End plus the client-reported reconnect count / connection quality
// sample gathered by RtcService during the call (session analytics requirement).
func (s *ConsultationService) EndWithStats(ctx context.Context, consultationID string, reconnectCount int, connectionQuality string) (*models.ConsultationWithDetails, error) {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return nil, err
	}
	if c == nil {
		return nil, errors.New("consultation not found")
	}
	duration := 0
	if c.StartedAt != nil {
		duration = int(time.Since(*c.StartedAt).Seconds())
	}
	if err := s.consultRepo.MarkEndedWithStats(ctx, consultationID, duration, reconnectCount, connectionQuality); err != nil {
		return nil, err
	}
	return s.consultRepo.GetWithDetails(ctx, consultationID)
}

// Cancel is the customer giving up while still searching/ringing.
func (s *ConsultationService) Cancel(ctx context.Context, consultationID, customerID string) error {
	return s.consultRepo.Cancel(ctx, consultationID, customerID)
}

// PendingForUser lists the incoming (ringing) consultation requests for the
// technician profile linked to this user account - populates the Incoming Request
// screen if opened directly instead of via the FCM push.
func (s *ConsultationService) PendingForUser(ctx context.Context, userID string) ([]models.ConsultationWithDetails, error) {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if tech == nil {
		return nil, errors.New("technician profile not found")
	}
	return s.consultRepo.ListPendingForTechnician(ctx, tech.ID)
}

// MyConsultations is the customer-facing call history (GET /consultations/mine) —
// every consultation they've ever requested, most recent first.
func (s *ConsultationService) MyConsultations(ctx context.Context, customerID string) ([]models.ConsultationWithDetails, error) {
	return s.consultRepo.ListForCustomer(ctx, customerID)
}

// Rate records the customer's rating for a consultation that resolved remotely (no
// escalated booking). Only allowed once the call has actually ended.
func (s *ConsultationService) Rate(ctx context.Context, consultationID, customerID string, rating int, comment string) error {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return err
	}
	if c == nil {
		return errors.New("consultation not found")
	}
	if c.CustomerID != customerID {
		return errors.New("not your consultation")
	}
	if c.Status != "ended" {
		return errors.New("consultation hasn't ended yet")
	}
	if c.TechnicianID == nil {
		return errors.New("no technician was assigned to this consultation")
	}
	if err := s.consultRepo.SetRating(ctx, consultationID, rating, comment); err != nil {
		return err
	}
	_, err = s.reviewRepo.CreateForConsultation(ctx, consultationID, customerID, *c.TechnicianID, rating, comment)
	return err
}

// Escalate is "Recommend On-site Visit" -> customer taps Yes: turns the consultation
// into a real booking for the SAME technician (reusing the normal booking-creation
// path, so it shows up in the technician's job list exactly like any other booking),
// and links the two records together.
func (s *ConsultationService) Escalate(ctx context.Context, consultationID, addressID, problemDescription, notes string, scheduledAt *time.Time) (*models.Booking, error) {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return nil, err
	}
	if c == nil {
		return nil, errors.New("consultation not found")
	}

	var notesPtr *string
	if notes != "" {
		notesPtr = &notes
	}

	booking := &models.Booking{
		CustomerID:         c.CustomerID,
		CategoryID:         c.CategoryID,
		AddressID:          addressID,
		TechnicianID:       c.TechnicianID,
		ProblemDescription: problemDescription,
		Notes:              notesPtr,
		ScheduledAt:        scheduledAt, // nil = ASAP; set = customer picked a date/time slot
	}

	var preferredTechnicianID string
	if c.TechnicianID != nil {
		preferredTechnicianID = *c.TechnicianID
	}
	created, err := s.bookingSvc.Create(ctx, booking, preferredTechnicianID)
	if err != nil {
		return nil, err
	}
	if err := s.consultRepo.SetEscalatedBooking(ctx, consultationID, created.ID); err != nil {
		return nil, err
	}
	return created, nil
}