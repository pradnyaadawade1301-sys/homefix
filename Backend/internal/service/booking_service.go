package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type BookingService struct {
	bookingRepo *repository.BookingRepository
	catRepo     *repository.CategoryRepository
	techRepo    *repository.TechnicianRepository
	paymentRepo *repository.PaymentRepository
	fcm         *FirebaseService
}

func NewBookingService(bookingRepo *repository.BookingRepository, catRepo *repository.CategoryRepository, techRepo *repository.TechnicianRepository, paymentRepo *repository.PaymentRepository, fcm *FirebaseService) *BookingService {
	return &BookingService{bookingRepo: bookingRepo, catRepo: catRepo, techRepo: techRepo, paymentRepo: paymentRepo, fcm: fcm}
}

// visitFeeAmount is the flat pre-visit inspection fee charged on bookings that
// come from an escalated video consultation (see RequireVisitFee below).
const visitFeeAmount = 99.0

// Create makes a new booking. If preferredTechnicianID is non-empty (customer
// picked a specific technician via "Book Now" on their profile), the booking
// is created and then immediately assigned to that technician (status jumps
// straight to "accepted") instead of sitting as "requested" waiting for any
// technician to accept it.
func (s *BookingService) Create(ctx context.Context, b *models.Booking, preferredTechnicianID string) (*models.Booking, error) {
	cat, err := s.catRepo.GetByID(ctx, b.CategoryID)
	if err != nil {
		return nil, err
	}
	if cat == nil {
		return nil, errors.New("category not found")
	}
	if b.EstimatedPrice == nil {
		price := cat.BasePrice
		b.EstimatedPrice = &price
	}

	created, err := s.bookingRepo.Create(ctx, b)
	if err != nil {
		return nil, err
	}

	if preferredTechnicianID != "" {
		tech, err := s.techRepo.GetByID(ctx, preferredTechnicianID)
		if err != nil {
			return nil, err
		}
		if tech == nil {
			return nil, errors.New("selected technician not found")
		}
		if err := s.bookingRepo.AssignTechnician(ctx, created.ID, preferredTechnicianID); err != nil {
			if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
				return nil, errors.New("this booking has already been assigned")
			}
			return nil, err
		}
		created.TechnicianID = &preferredTechnicianID
		created.Status = models.BookingAccepted

		if s.fcm != nil {
			_ = s.fcm.SendToUser(ctx, tech.UserID, "New booking request",
				"You have a new booking request.",
				map[string]string{"booking_id": created.ID, "type": "booking_assigned"})
		}
	}

	return created, nil
}

func (s *BookingService) Get(ctx context.Context, id string) (*models.Booking, error) {
	return s.bookingRepo.GetByID(ctx, id)
}

// GetDetail returns a booking with the joined customer/technician/address info.
func (s *BookingService) GetDetail(ctx context.Context, id string) (*models.BookingDetail, error) {
	return s.bookingRepo.GetDetailByID(ctx, id)
}

func (s *BookingService) ListForCustomer(ctx context.Context, customerID string) ([]models.Booking, error) {
	return s.bookingRepo.ListByCustomer(ctx, customerID)
}

func (s *BookingService) ListForTechnician(ctx context.Context, technicianID string) ([]models.Booking, error) {
	return s.bookingRepo.ListByTechnician(ctx, technicianID)
}

// TechnicianOwnedByUser reports whether the given technician record belongs to userID —
// used to stop one technician from viewing another technician's bookings via URL param.
func (s *BookingService) TechnicianOwnedByUser(ctx context.Context, technicianID, userID string) (bool, error) {
	tech, err := s.techRepo.GetByID(ctx, technicianID)
	if err != nil {
		return false, err
	}
	if tech == nil {
		return false, nil
	}
	return tech.UserID == userID, nil
}

// ListForCustomerDetailed powers the customer's "My Bookings" screen — each booking
// carries the assigned technician's name/phone/rating once one is assigned.
func (s *BookingService) ListForCustomerDetailed(ctx context.Context, customerID string) ([]models.BookingDetail, error) {
	return s.bookingRepo.ListByCustomerDetailed(ctx, customerID)
}

// ListForTechnicianDetailed powers the technician's "My Jobs" screen — each booking
// carries the customer's name/phone and the job address.
func (s *BookingService) ListForTechnicianDetailed(ctx context.Context, technicianID string) ([]models.BookingDetail, error) {
	return s.bookingRepo.ListByTechnicianDetailed(ctx, technicianID)
}

// Accept assigns a technician to a booking and notifies the customer via real FCM push.
func (s *BookingService) Accept(ctx context.Context, bookingID, technicianID string) error {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}
	if b.Status != models.BookingRequested {
		return errors.New("booking is not in a requested state")
	}

	// AssignTechnician re-checks status='requested' atomically inside its own
	// UPDATE, so even if two technicians pass the check above at the same
	// instant, only one of them can actually win here — the other gets
	// ErrBookingAlreadyAssigned instead of silently overwriting the first.
	if err := s.bookingRepo.AssignTechnician(ctx, bookingID, technicianID); err != nil {
		if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
			return errors.New("this booking has already been accepted by another technician")
		}
		return err
	}

	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Technician assigned",
			"A technician has accepted your booking and is on the way.",
			map[string]string{"booking_id": bookingID, "type": "booking_accepted"})
	}
	return nil
}

// Decline is the technician-side counterpart of Accept — a technician turning
// down a booking that was routed to them while it's still 'requested'.
// bookingRepo.Decline atomically clears technician_id and puts the booking
// back to 'requested' only if it was still assigned to this exact technician,
// so a stale/duplicate decline can't clobber a booking someone else already
// accepted in the meantime.
func (s *BookingService) Decline(ctx context.Context, bookingID, technicianID string) error {
	if err := s.bookingRepo.Decline(ctx, bookingID, technicianID); err != nil {
		if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
			return errors.New("this booking is no longer assigned to you")
		}
		return err
	}
	return nil
}

func (s *BookingService) UpdateStatus(ctx context.Context, bookingID, status, note string) error {
	if !models.ValidBookingStatuses[status] {
		return errors.New("invalid status: " + status)
	}
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}
	if err := s.bookingRepo.UpdateStatus(ctx, bookingID, status, note); err != nil {
		return err
	}
	// The moment a technician marks themselves "arrived", generate a fresh
	// OTP and store it against the booking. No SMS/push is sent — the
	// customer's own Booking Tracking screen fetches and displays this code
	// directly (see GetOTP below), the same way ride-hailing apps show a
	// start-ride PIN on-screen rather than texting it.
	if status == models.BookingArrived {
		otp := generateOTP()
		if err := s.bookingRepo.SetOTP(ctx, bookingID, otp); err != nil {
			return err
		}
	}
	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Booking update",
			"Your booking status changed to "+status, map[string]string{"booking_id": bookingID, "type": "booking_status"})
	}
	return nil
}

// RequireVisitFee marks a booking as needing the ₹99 pre-visit inspection fee
// before the technician can head out. Called once, right when a video
// consultation is escalated into a booking (see ConsultationService.Escalate)
// — direct bookings (never routed through a consultation) never call this, so
// their visit_fee_status stays unset and no fee is required.
func (s *BookingService) RequireVisitFee(ctx context.Context, bookingID string) error {
	return s.bookingRepo.SetVisitFeeRequired(ctx, bookingID, visitFeeAmount)
}

// MarkVisitFeePaid flips a booking's visit-fee status to "paid" once a
// verified payment for it has actually come in (see UpiService.ConfirmPayment).
func (s *BookingService) MarkVisitFeePaid(ctx context.Context, bookingID string) error {
	return s.bookingRepo.SetVisitFeeStatus(ctx, bookingID, "paid")
}

// Complete records the technician's final_price — this IS the invoice, since
// it's the only number the app ever asks the customer to pay (see
// UpiService.CreateOrder, which validates the payment amount against it).
// warrantyEnabled/warrantyDays are the technician's optional "Warranty: Yes"
// choice — warrantyDays MUST be one of the category's configured
// warranty_options (see CategoryRepository/UpdateWarrantyOptions); a
// technician can never set an arbitrary or unlimited period, and if
// warrantyEnabled is false any warrantyDays value is ignored. The FCM push
// here is the only signal the customer gets that a bill is ready; without it
// they'd only find out by happening to reopen the booking.
func (s *BookingService) Complete(ctx context.Context, bookingID string, finalPrice float64, warrantyEnabled bool, warrantyDays *int) error {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}

	const maxWarrantyDays = 3650 // 10 years — sanity ceiling only
	if warrantyEnabled {
		if warrantyDays == nil {
			return errors.New("warranty duration is required when warranty is enabled")
		}
		if *warrantyDays <= 0 {
			return errors.New("warranty duration must be a positive number of days")
		}
		if *warrantyDays > maxWarrantyDays {
			return fmt.Errorf("warranty duration must be %d days or fewer", maxWarrantyDays)
		}
	} else {
		warrantyDays = nil
	}

	if err := s.bookingRepo.SetFinalPrice(ctx, bookingID, finalPrice); err != nil {
		return err
	}
	if err := s.bookingRepo.SetWarranty(ctx, bookingID, warrantyEnabled, warrantyDays); err != nil {
		return err
	}
	if err := s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingCompleted, "Job completed"); err != nil {
		return err
	}

	if s.fcm != nil {
		body := fmt.Sprintf("Your technician has completed the job. Amount due: \u20b9%.2f. Tap to pay.", finalPrice)
		if warrantyEnabled && warrantyDays != nil {
			body += fmt.Sprintf(" This service is covered by a %d-day warranty.", *warrantyDays)
		}
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Invoice ready", body,
			map[string]string{"booking_id": bookingID, "type": "invoice_ready", "final_price": fmt.Sprintf("%.2f", finalPrice)})
	}
	return nil
}

// RaiseWarrantyClaim is the customer tapping "Claim Warranty" on a completed,
// still-under-warranty booking. It creates a brand-new booking — reusing the
// entire existing accept/track/complete/pay lifecycle rather than a separate
// claims system — tagged as a warranty claim and linked back to the original
// via warranty_claim_of, so it shows up traceably on both sides.
func (s *BookingService) RaiseWarrantyClaim(ctx context.Context, customerID, originalBookingID, note string) (*models.Booking, error) {
	original, err := s.bookingRepo.GetByID(ctx, originalBookingID)
	if err != nil {
		return nil, err
	}
	if original == nil {
		return nil, errors.New("original booking not found")
	}
	if original.CustomerID != customerID {
		return nil, errors.New("this booking does not belong to you")
	}
	if original.Status != models.BookingCompleted {
		return nil, errors.New("a warranty claim can only be raised against a completed booking")
	}
	if original.IsWarrantyClaim {
		return nil, errors.New("a warranty claim cannot itself be claimed again")
	}
	if !original.WarrantyEnabled || original.WarrantyExpiresAt == nil {
		return nil, errors.New("no warranty was provided for this service")
	}
	if time.Now().After(*original.WarrantyExpiresAt) {
		return nil, errors.New("the warranty period for this service has expired")
	}

	desc := "Warranty claim for booking " + original.ServiceCode
	if note != "" {
		desc += ": " + note
	}
	originalID := original.ID
	newBooking := &models.Booking{
		CustomerID:         customerID,
		CategoryID:         original.CategoryID,
		AddressID:          original.AddressID,
		ProblemDescription: desc,
		IsWarrantyClaim:    true,
		WarrantyClaimOf:    &originalID,
	}
	created, err := s.bookingRepo.Create(ctx, newBooking)
	if err != nil {
		return nil, err
	}

	// Prefer routing straight back to whoever did the original job — same
	// technician already knows the site/problem. Falls back to sitting as
	// "requested" for any technician in the category if that fails (e.g.
	// they're no longer active), same as a normal booking with no
	// preference would.
	if original.TechnicianID != nil {
		if err := s.bookingRepo.AssignTechnician(ctx, created.ID, *original.TechnicianID); err == nil {
			created.TechnicianID = original.TechnicianID
			created.Status = models.BookingAccepted
			if s.fcm != nil {
				tech, techErr := s.techRepo.GetByID(ctx, *original.TechnicianID)
				if techErr == nil && tech != nil {
					_ = s.fcm.SendToUser(ctx, tech.UserID, "Warranty claim raised",
						"A customer has raised a warranty claim on a completed job ("+original.ServiceCode+").",
						map[string]string{"booking_id": created.ID, "type": "warranty_claim", "original_booking_id": originalID})
				}
			}
		}
	}

	return created, nil
}

func (s *BookingService) Cancel(ctx context.Context, bookingID, reason string) error {
	return s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingCancelled, reason)
}

func (s *BookingService) History(ctx context.Context, bookingID string) ([]models.BookingStatusHistory, error) {
	return s.bookingRepo.History(ctx, bookingID)
}

// RepeatCustomers powers the technician's "My Customers" screen — customers who
// have booked this technician more than once.
func (s *BookingService) RepeatCustomers(ctx context.Context, technicianID string) ([]models.RepeatCustomer, error) {
	return s.bookingRepo.ListRepeatCustomersByTechnician(ctx, technicianID)
}

// RepeatTechnicians is the customer-side mirror of RepeatCustomers — powers the
// customer's "My Technicians" screen with technicians they've booked more than
// once.
func (s *BookingService) RepeatTechnicians(ctx context.Context, customerID string) ([]models.RepeatTechnician, error) {
	return s.bookingRepo.ListRepeatTechniciansByCustomer(ctx, customerID)
}

// ServiceHistory returns every past booking a specific customer has made with a
// specific technician, each with its payment/pricing-tier info attached — reached
// from the technician's repeat-customers list by tapping a customer.
func (s *BookingService) ServiceHistory(ctx context.Context, technicianID, customerID string) ([]models.ServiceHistoryEntry, error) {
	bookings, err := s.bookingRepo.ListByCustomerAndTechnicianDetailed(ctx, customerID, technicianID)
	if err != nil {
		return nil, err
	}

	out := make([]models.ServiceHistoryEntry, 0, len(bookings))
	for _, b := range bookings {
		entry := models.ServiceHistoryEntry{BookingDetail: b}
		if s.paymentRepo != nil {
			if p, err := s.paymentRepo.GetByBookingID(ctx, b.ID); err == nil && p != nil {
				entry.Payment = &models.ServiceHistoryPayment{
					Amount:                p.Amount,
					Status:                p.Status,
					IsRepeatCustomer:      p.IsRepeatCustomer,
					RepeatDiscountPercent: p.RepeatDiscountPercent,
					RepeatDiscountAmount:  p.RepeatDiscountAmount,
				}
			}
		}
		out = append(out, entry)
	}
	return out, nil
}

// --- Booking chat ---
//
// Only the booking's customer, or the technician actually assigned to it,
// may read/send messages. userRole comes from the JWT claims set by the auth
// middleware; senderRole recorded on each message is derived from that, not
// trusted from the client body.

func (s *BookingService) SendMessage(ctx context.Context, bookingID, userID, userRole, content string) (*models.BookingMessage, error) {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return nil, err
	}
	if b == nil {
		return nil, errors.New("booking not found")
	}

	senderRole, err := s.resolveBookingParticipantRole(ctx, b, userID, userRole)
	if err != nil {
		return nil, err
	}

	msg := &models.BookingMessage{BookingID: bookingID, SenderID: userID, SenderRole: senderRole, Content: content}
	created, err := s.bookingRepo.CreateMessage(ctx, msg)
	if err != nil {
		return nil, err
	}

	if s.fcm != nil {
		recipientID := b.CustomerID
		if senderRole == "customer" && b.TechnicianID != nil {
			if tech, err := s.techRepo.GetByID(ctx, *b.TechnicianID); err == nil && tech != nil {
				recipientID = tech.UserID
			}
		}
		if recipientID != userID {
			_ = s.fcm.SendToUser(ctx, recipientID, "New message",
				content, map[string]string{"booking_id": bookingID, "type": "booking_message"})
		}
	}

	return created, nil
}

func (s *BookingService) ListMessages(ctx context.Context, bookingID, userID, userRole string) ([]models.BookingMessage, error) {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return nil, err
	}
	if b == nil {
		return nil, errors.New("booking not found")
	}
	if _, err := s.resolveBookingParticipantRole(ctx, b, userID, userRole); err != nil {
		return nil, err
	}
	return s.bookingRepo.ListMessages(ctx, bookingID)
}

// resolveBookingParticipantRole confirms userID is actually a party to
// booking b (its customer, or its assigned technician) and returns which
// side they're on ("customer" | "technician"). Admins may also read/send for
// support purposes — recorded as "admin" (its own distinct role) rather than
// impersonating "technician", so the customer isn't misled about who they're
// actually talking to.
func (s *BookingService) resolveBookingParticipantRole(ctx context.Context, b *models.Booking, userID, userRole string) (string, error) {
	if userID == b.CustomerID {
		return "customer", nil
	}
	if userRole == "admin" {
		return "admin", nil
	}
	if b.TechnicianID != nil {
		tech, err := s.techRepo.GetByID(ctx, *b.TechnicianID)
		if err != nil {
			return "", err
		}
		if tech != nil && tech.UserID == userID {
			return "technician", nil
		}
	}
	return "", errors.New("you are not a participant in this booking")
}

// generateOTP returns a random 4-digit numeric code shown to the customer
// and read out to the technician on-site (see UpdateStatus above).
func generateOTP() string {
	n := time.Now().UnixNano() % 10000
	if n < 0 {
		n = -n
	}
	return fmt.Sprintf("%04d", n)
}

// VerifyOTP is called by the technician's app once the customer has read
// out the code shown on their screen. Success moves the booking straight
// into "inspecting" — the technician can now legitimately start diagnosing
// the problem and later raise an estimate.
func (s *BookingService) VerifyOTP(ctx context.Context, bookingID, otp string) (bool, error) {
	ok, err := s.bookingRepo.VerifyOTP(ctx, bookingID, otp)
	if err != nil || !ok {
		return ok, err
	}
	if err := s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingInspecting, "OTP verified, service started"); err != nil {
		return true, err
	}
	return true, nil
}

// GetOTP returns the current, unverified OTP for a booking so the
// customer's own app can display it on-screen — the same pattern as a
// ride-hailing app's start-ride PIN. Only the booking's own customer should
// ever be allowed to call this (enforced in the handler); it is never sent
// over SMS or push, and returns "" once already verified or if none has
// been generated yet (e.g. technician hasn't marked "arrived").
func (s *BookingService) GetOTP(ctx context.Context, bookingID string) (string, error) {
	return s.bookingRepo.GetOTP(ctx, bookingID)
}

// TechnicianLocation exposes the assigned technician's last known position
// for the customer's live tracking screen. Returns (nil, nil, nil, nil) if
// no technician is assigned yet, so the caller can render "finding
// technician" instead of a map.
func (s *BookingService) TechnicianLocation(ctx context.Context, bookingID string) (lat, lng *float64, updatedAt *time.Time, err error) {
	return s.bookingRepo.TechnicianLocationForBooking(ctx, bookingID)
}

// SubmitEstimate is called by the technician after inspecting the problem.
// Calling it again (e.g. after the customer chose "Discuss") simply
// replaces the items/total and resets status to pending for a fresh
// decision — see BookingRepository.UpsertEstimate.
func (s *BookingService) SubmitEstimate(ctx context.Context, bookingID string, items []models.BookingEstimateItem, note string) (*models.BookingEstimate, error) {
	if len(items) == 0 {
		return nil, errors.New("estimate must have at least one line item")
	}
	est, err := s.bookingRepo.UpsertEstimate(ctx, bookingID, items, note)
	if err != nil {
		return nil, err
	}
	if b, _ := s.bookingRepo.GetByID(ctx, bookingID); b != nil && s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Service estimate ready",
			fmt.Sprintf("Your technician has sent an estimate of \u20b9%.0f", est.Total),
			map[string]string{"booking_id": bookingID, "type": "booking_estimate"})
	}
	return est, nil
}

func (s *BookingService) GetEstimate(ctx context.Context, bookingID string) (*models.BookingEstimate, error) {
	return s.bookingRepo.GetEstimate(ctx, bookingID)
}

// RespondToEstimate records the customer's Approve/Decline decision.
// "Discuss" isn't a persisted status here — it's just the customer opening
// chat with the technician, who then calls SubmitEstimate again with
// revised numbers. Approving moves the booking into "repair_in_progress" so
// the technician is unambiguously authorised to start paid work.
func (s *BookingService) RespondToEstimate(ctx context.Context, bookingID, decision string) error {
	var status string
	switch decision {
	case "approve":
		status = models.EstimateApproved
	case "decline":
		status = models.EstimateDeclined
	default:
		return errors.New("decision must be 'approve' or 'decline'")
	}
	if err := s.bookingRepo.SetEstimateStatus(ctx, bookingID, status); err != nil {
		return err
	}
	if status == models.EstimateApproved {
		return s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingRepairInProgress, "Customer approved estimate")
	}
	return s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingCancelled, "Customer declined estimate")
}

func (s *BookingService) AddServicePhoto(ctx context.Context, bookingID, photoURL, photoType string) (*models.BookingServicePhoto, error) {
	if photoType != "before" && photoType != "after" {
		return nil, errors.New("photo_type must be 'before' or 'after'")
	}
	return s.bookingRepo.AddServicePhoto(ctx, bookingID, photoURL, photoType)
}

func (s *BookingService) ListServicePhotos(ctx context.Context, bookingID string) ([]models.BookingServicePhoto, error) {
	return s.bookingRepo.ListServicePhotos(ctx, bookingID)
}
