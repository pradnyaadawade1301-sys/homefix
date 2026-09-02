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

// minScheduleLeadTime stops someone from "scheduling" a slot that's basically
// right now (which should just be Consult Now instead) or in the past.
const minScheduleLeadTime = 10 * time.Minute

// Request is "Start Live Consultation". Two modes based on scheduledAt:
//
//   - scheduledAt == nil: INSTANT flow (unchanged). If preferredTechnicianID is
//     set, only that technician is rung. Otherwise falls back to
//     nearest-available-in-category matching.
//
//   - scheduledAt != nil: SCHEDULED flow. The technician is matched the same way,
//     but is NOT rung immediately — they're asked to confirm holding that slot
//     (status 'scheduled' -> 'confirmed'). The actual ring happens later, when
//     the slot time arrives, via PromoteDueScheduled.
func (s *ConsultationService) Request(ctx context.Context, customerID, categoryID, preferredTechnicianID string, lat, lng *float64, scheduledAt *time.Time) (*models.ConsultationWithDetails, error) {
	if scheduledAt != nil && scheduledAt.Before(time.Now().Add(minScheduleLeadTime)) {
		return nil, errors.New("please pick a time at least 10 minutes from now")
	}

	c, err := s.consultRepo.Create(ctx, customerID, categoryID, defaultConsultationFee, scheduledAt)
	if err != nil {
		return nil, err
	}
	isScheduled := scheduledAt != nil

	assign := func(technicianID string) error {
		if isScheduled {
			return s.consultRepo.AssignTechnicianScheduled(ctx, c.ID, technicianID)
		}
		return s.consultRepo.AssignTechnician(ctx, c.ID, technicianID)
	}

	notify := func(technicianUserID string) {
		if s.fcm == nil {
			return
		}
		if isScheduled {
			_ = s.fcm.SendToUser(ctx, technicianUserID, "New consultation booking request",
				"A customer wants to schedule a live video consultation with you at "+scheduledAt.Format("2 Jan, 3:04 PM")+". Please confirm.",
				map[string]string{"consultation_id": c.ID, "type": "consultation_scheduled_request"})
			return
		}
		_ = s.fcm.SendToUser(ctx, technicianUserID, "New consultation request",
			"A customer is requesting a live video consultation.",
			map[string]string{"consultation_id": c.ID, "type": "consultation_request"})
	}

	if preferredTechnicianID != "" {
		tech, err := s.techRepo.GetByID(ctx, preferredTechnicianID)
		if err != nil {
			return nil, err
		}
		if tech == nil || (!isScheduled && !tech.IsAvailable) {
			if err := s.consultRepo.UpdateStatus(ctx, c.ID, "no_technician"); err != nil {
				return nil, err
			}
			return s.consultRepo.GetWithDetails(ctx, c.ID)
		}
		if err := assign(tech.ID); err != nil {
			return nil, err
		}
		notify(tech.UserID)
		return s.consultRepo.GetWithDetails(ctx, c.ID)
	}

	// Fallback: nearest-available-by-category matching. For the scheduled flow
	// "available right now" isn't the right signal (the slot might be hours from
	// now), so we just pick the nearest technician in the category regardless of
	// their current live-availability toggle.
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
		if err := assign(assignedTech.ID); err != nil {
			return nil, err
		}
		tech, techErr := s.techRepo.GetByID(ctx, assignedTech.ID)
		if techErr == nil && tech != nil {
			notify(tech.UserID)
		}
	}

	return s.consultRepo.GetWithDetails(ctx, c.ID)
}

// ConfirmScheduled is the technician confirming they can take a scheduled slot
// (status 'scheduled' -> 'confirmed'). Distinct from Accept, which is for the
// instant/ringing flow — a scheduled consultation isn't "accepted" until its slot
// actually arrives and it becomes a real incoming call (see PromoteDueScheduled).
func (s *ConsultationService) ConfirmScheduled(ctx context.Context, consultationID, technicianID string) (*models.ConsultationWithDetails, error) {
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
	if c.Status != "scheduled" {
		return nil, errors.New("this consultation is not awaiting confirmation")
	}
	if err := s.consultRepo.UpdateStatus(ctx, consultationID, "confirmed"); err != nil {
		return nil, err
	}
	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Consultation confirmed",
			"Your technician has confirmed your scheduled consultation.",
			map[string]string{"consultation_id": consultationID, "type": "consultation_confirmed"})
	}
	return s.consultRepo.GetWithDetails(ctx, consultationID)
}

// ConfirmScheduledByUser is the ConfirmScheduled counterpart for the Flutter app's
// button, which only knows the logged-in user id.
func (s *ConsultationService) ConfirmScheduledByUser(ctx context.Context, consultationID, userID string) (*models.ConsultationWithDetails, error) {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if tech == nil {
		return nil, errors.New("technician profile not found")
	}
	return s.ConfirmScheduled(ctx, consultationID, tech.ID)
}

// DeclineScheduled is the technician declining a scheduled slot ahead of time.
// Kept simple like Reject: marks 'rejected' rather than auto-retrying another
// technician, so the customer gets a clear signal and can reschedule/re-request.
// reason is optional free text the technician gives (e.g. "Not available at that
// time") — stored and passed on to the customer via FCM so "declined" isn't a
// dead end with no explanation.
func (s *ConsultationService) DeclineScheduled(ctx context.Context, consultationID, technicianID, reason string) error {
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
	if err := s.consultRepo.UpdateStatusWithReason(ctx, consultationID, "rejected", reason); err != nil {
		return err
	}
	if s.fcm != nil {
		body := "The technician can't make your scheduled consultation slot. Please pick another time."
		if reason != "" {
			body = "The technician can't make your scheduled consultation slot: " + reason + ". Please pick another time."
		}
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Consultation declined", body,
			map[string]string{"consultation_id": consultationID, "type": "consultation_scheduled_declined", "reason": reason})
	}
	return nil
}

func (s *ConsultationService) DeclineScheduledByUser(ctx context.Context, consultationID, userID, reason string) error {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	if tech == nil {
		return errors.New("technician profile not found")
	}
	return s.DeclineScheduled(ctx, consultationID, tech.ID, reason)
}

// PromoteDueScheduled is polled periodically (see main.go) to find every
// 'confirmed' scheduled consultation whose slot time has arrived, flip it to
// 'ringing' (the same terminal state the instant flow lands in), and notify both
// sides — "your consultation is starting now". From this point on it behaves
// exactly like an instant call: the technician sees it on their incoming-request
// card and taps Accept, which is what actually opens the WebRTC room.
func (s *ConsultationService) PromoteDueScheduled(ctx context.Context) (int, error) {
	due, err := s.consultRepo.DueForRinging(ctx)
	if err != nil {
		return 0, err
	}
	promoted := 0
	for _, c := range due {
		if err := s.consultRepo.PromoteToRinging(ctx, c.ID); err != nil {
			continue // don't let one bad row block the rest of the batch
		}
		promoted++

		if s.fcm == nil || c.TechnicianID == nil {
			continue
		}
		tech, err := s.techRepo.GetByID(ctx, *c.TechnicianID)
		if err == nil && tech != nil {
			_ = s.fcm.SendToUser(ctx, tech.UserID, "Consultation starting now",
				"Your scheduled consultation is starting — tap to join.",
				map[string]string{"consultation_id": c.ID, "type": "consultation_request"})
		}
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Consultation starting now",
			"Your scheduled consultation is starting — connecting you now.",
			map[string]string{"consultation_id": c.ID, "type": "consultation_scheduled_starting"})
	}
	return promoted, nil
}

// UpcomingForUser lists the technician's scheduled/confirmed consultations —
// distinct from PendingForUser (which is the urgent "ringing right now" queue).
func (s *ConsultationService) UpcomingForUser(ctx context.Context, userID string) ([]models.ConsultationWithDetails, error) {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if tech == nil {
		return nil, errors.New("technician profile not found")
	}
	return s.consultRepo.ListUpcomingForTechnician(ctx, tech.ID)
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

// Reject is the technician tapping [Reject] on an instant/ringing request. reason is
// optional free text explaining why — same idea as DeclineScheduled, kept as a
// separate method since instant and scheduled requests are declined from different
// screens with different urgency.
func (s *ConsultationService) Reject(ctx context.Context, consultationID, technicianID, reason string) error {
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
	if err := s.consultRepo.UpdateStatusWithReason(ctx, consultationID, "rejected", reason); err != nil {
		return err
	}
	// Notify the customer their call wasn't answered — otherwise, if the app is
	// backgrounded, they're left staring at "Searching..." with no signal at all.
	if s.fcm != nil {
		body := "The technician couldn't take your live video consultation right now."
		if reason != "" {
			body = "The technician couldn't take your live video consultation: " + reason
		}
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Call not answered", body,
			map[string]string{"consultation_id": consultationID, "type": "consultation_rejected", "reason": reason})
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
func (s *ConsultationService) RejectByUser(ctx context.Context, consultationID, userID, reason string) error {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	if tech == nil {
		return errors.New("technician profile not found")
	}
	return s.Reject(ctx, consultationID, tech.ID, reason)
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

// Cancel is the customer giving up while still searching/ringing/scheduled/confirmed.
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
// RecommendOnsite is the technician sending a simple "here's what I found and
// what it'll cost" note right after the call ends, instead of the call just
// hanging up with nothing further. Only the technician who was actually on
// this call can send one, and only once the call has actually happened
// (status must be "ended" or "in_call" — a stray recommend on a call that
// never connected would be confusing on the customer's side).
func (s *ConsultationService) RecommendOnsite(ctx context.Context, consultationID, technicianID, summary string, price *float64) (*models.ConsultationWithDetails, error) {
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
	if c.Status != "ended" && c.Status != "in_call" {
		return nil, errors.New("can only send a recommendation for a call that has taken place")
	}
	if summary == "" {
		return nil, errors.New("summary is required")
	}
	if err := s.consultRepo.SetRecommendation(ctx, consultationID, summary, price); err != nil {
		return nil, err
	}
	// Notify the customer there's something waiting for their Accept/Decline —
	// otherwise this just silently sits in the DB until they happen to reopen
	// the call-ended screen on their own.
	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, c.CustomerID, "Technician's recommendation is ready",
			"Your technician sent a recommendation after the call. Review it to book a visit.",
			map[string]string{"consultation_id": consultationID, "type": "consultation_recommendation"})
	}
	return s.consultRepo.GetWithDetails(ctx, consultationID)
}

// RecommendOnsiteByUser is the Send-button counterpart of RecommendOnsite,
// resolving the logged-in technician's own profile server-side — mirrors
// AcceptByUser/RejectByUser above.
func (s *ConsultationService) RecommendOnsiteByUser(ctx context.Context, consultationID, userID, summary string, price *float64) (*models.ConsultationWithDetails, error) {
	tech, err := s.techRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if tech == nil {
		return nil, errors.New("technician profile not found")
	}
	return s.RecommendOnsite(ctx, consultationID, tech.ID, summary, price)
}

// DeclineRecommendation is the customer tapping [Decline] on the technician's
// post-call recommendation — no booking gets created, and the recommendation
// can't be re-accepted afterwards (they'd need a fresh call for that).
func (s *ConsultationService) DeclineRecommendation(ctx context.Context, consultationID, customerID string) error {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return err
	}
	if c == nil {
		return errors.New("consultation not found")
	}
	if c.CustomerID != customerID {
		return errors.New("this consultation does not belong to you")
	}
	if c.RecommendationStatus == nil || *c.RecommendationStatus != "pending" {
		return errors.New("there is no pending recommendation to decline")
	}
	return s.consultRepo.UpdateRecommendationStatus(ctx, consultationID, "declined")
}

func (s *ConsultationService) Escalate(ctx context.Context, consultationID, addressID, problemDescription, notes string, scheduledAt *time.Time) (*models.Booking, error) {
	c, err := s.consultRepo.GetByID(ctx, consultationID)
	if err != nil {
		return nil, err
	}
	if c == nil {
		return nil, errors.New("consultation not found")
	}

	// If the technician sent a post-call recommendation and the caller (the
	// customer, accepting it) didn't type their own problem description,
	// fall back to the technician's summary/price rather than creating a
	// booking with an empty problem description or the plain category base
	// price. Explicit values from the request always win, so a customer
	// typing their own note still overrides the technician's summary.
	if problemDescription == "" && c.RecommendationSummary != nil {
		problemDescription = *c.RecommendationSummary
	}

	booking := &models.Booking{
		CustomerID:         c.CustomerID,
		CategoryID:         c.CategoryID,
		AddressID:          addressID,
		TechnicianID:       c.TechnicianID,
		ProblemDescription: problemDescription,
		ScheduledAt:        scheduledAt,
		Notes:              &notes, // nil = ASAP; set = customer picked a date/time slot
	}
	if c.RecommendationPrice != nil {
		booking.EstimatedPrice = c.RecommendationPrice
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
	// Bookings that come from a VC consultation require the ₹99 pre-visit
	// inspection fee before the technician can head out — direct bookings
	// (never routed through Escalate) don't.
	if err := s.bookingSvc.RequireVisitFee(ctx, created.ID); err != nil {
		return nil, err
	}
	// A pending recommendation being turned into a booking IS the "accept" —
	// close it out so it can't also be separately declined afterwards.
	if c.RecommendationStatus != nil && *c.RecommendationStatus == "pending" {
		if err := s.consultRepo.UpdateRecommendationStatus(ctx, consultationID, "accepted"); err != nil {
			return nil, err
		}
	}
	return created, nil
}