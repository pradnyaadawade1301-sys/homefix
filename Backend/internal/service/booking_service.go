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
	userRepo    *repository.UserRepository
	fcm         *FirebaseService
}

func NewBookingService(bookingRepo *repository.BookingRepository, catRepo *repository.CategoryRepository, techRepo *repository.TechnicianRepository, paymentRepo *repository.PaymentRepository, userRepo *repository.UserRepository, fcm *FirebaseService) *BookingService {
	return &BookingService{bookingRepo: bookingRepo, catRepo: catRepo, techRepo: techRepo, paymentRepo: paymentRepo, userRepo: userRepo, fcm: fcm}
}

// Create makes a new booking. If preferredTechnicianID is non-empty (customer
// picked a specific technician via "Book Now" on their profile), the booking
// is created and routed to that technician as a PENDING request — status goes
// to "pending_technician", NOT "accepted". The technician still has to
// explicitly Accept or Reject it before it becomes "accepted".
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
		if err := s.bookingRepo.AssignPendingTechnician(ctx, created.ID, preferredTechnicianID); err != nil {
			if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
				return nil, errors.New("this booking has already been assigned")
			}
			return nil, err
		}
		created.TechnicianID = &preferredTechnicianID
		created.Status = models.BookingPendingTechnician

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

// Accept is called by a technician tapping "Accept" on a job. It handles
// BOTH ways a job can reach a technician:
//   - status == "requested": an open job from the general pool — the
//     technician is self-assigning it for the first time (AssignTechnician).
//   - status == "pending_technician": a job routed specifically to this
//     technician via "Book Now" — they're confirming it (ConfirmAssignment).
func (s *BookingService) Accept(ctx context.Context, bookingID, technicianID string) error {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}

	switch b.Status {
	case models.BookingRequested:
		if err := s.bookingRepo.AssignTechnician(ctx, bookingID, technicianID); err != nil {
			if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
				return errors.New("this booking has already been accepted by another technician")
			}
			return err
		}
	case models.BookingPendingTechnician:
		if b.TechnicianID == nil || *b.TechnicianID != technicianID {
			return errors.New("this booking was not routed to you")
		}
		if err := s.bookingRepo.ConfirmAssignment(ctx, bookingID, technicianID); err != nil {
			if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
				return errors.New("this booking is no longer awaiting your confirmation")
			}
			return err
		}
	default:
		return errors.New("booking is not in a requested state")
	}

	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Technician assigned",
			"A technician has accepted your booking and is on the way.",
			map[string]string{"booking_id": bookingID, "type": "booking_accepted"})
	}
	return nil
}

// Reject is called by a technician tapping "Reject" on a job routed to them
// via "Book Now" (status == "pending_technician"). It puts the booking back
// into the open pool (status -> "requested", technician_id cleared) so
// another technician can pick it up, and notifies the customer.
func (s *BookingService) Reject(ctx context.Context, bookingID, technicianID string) error {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}
	if b.TechnicianID == nil || *b.TechnicianID != technicianID {
		return errors.New("this booking was not routed to you")
	}

	if err := s.bookingRepo.Decline(ctx, bookingID, technicianID); err != nil {
		if errors.Is(err, repository.ErrBookingAlreadyAssigned) {
			return errors.New("this booking is no longer awaiting your response")
		}
		return err
	}

	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Finding another technician",
			"Your preferred technician couldn't take this job. We're finding another one for you.",
			map[string]string{"booking_id": bookingID, "type": "booking_rejected"})
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
	if status == models.BookingArrived {
		otp := generateOTP()
		if err := s.bookingRepo.SetOTP(ctx, bookingID, otp); err != nil {
			return err
		}
	}
	if s.fcm != nil {
		techName := ""
		if b.TechnicianID != nil {
			if n, err := s.techRepo.GetNameByID(ctx, *b.TechnicianID); err == nil {
				techName = n
			}
		}
		body := "Your booking status changed to " + status
		data := map[string]string{"booking_id": bookingID, "type": "booking_status"}
		if techName != "" {
			body = techName + ": your booking status changed to " + status
			data["sender_name"] = techName
		}
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Booking update", body, data)
	}
	return nil
}

func (s *BookingService) Complete(ctx context.Context, bookingID string, finalPrice float64, warrantyEnabled bool, warrantyDays *int, warrantyDescription *string) error {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}

	if warrantyEnabled {
		if warrantyDays == nil {
			return errors.New("warranty duration is required when warranty is enabled")
		}
		// Previously restricted to whatever the category's admin-configured
		// warranty_options whitelist allowed (e.g. only 7/15/30/90 days) —
		// removed per product decision so the technician can offer any
		// duration that makes sense for the job. Only guard left: it has to
		// be a real, positive number of days.
		if *warrantyDays <= 0 {
			return errors.New("warranty duration must be a positive number of days")
		}
	} else {
		warrantyDays = nil
		warrantyDescription = nil
	}

	if err := s.bookingRepo.SetFinalPrice(ctx, bookingID, finalPrice); err != nil {
		return err
	}
	if err := s.bookingRepo.SetWarranty(ctx, bookingID, warrantyEnabled, warrantyDays, warrantyDescription); err != nil {
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

func (s *BookingService) AuthorizeCallParticipant(ctx context.Context, userID, bookingID string) (*models.BookingDetail, error) {
	b, err := s.GetDetail(ctx, bookingID)
	if err != nil {
		return nil, err
	}
	if b == nil {
		return nil, errors.New("booking not found")
	}
	if userID == b.CustomerID {
		return b, nil
	}
	if b.TechnicianID != nil {
		tech, err := s.techRepo.GetByUserID(ctx, userID)
		if err == nil && tech != nil && tech.ID == *b.TechnicianID {
			return b, nil
		}
	}
	return nil, errors.New("not a participant of this booking")
}

func (s *BookingService) InitiateCall(ctx context.Context, technicianUserID, bookingID string) (*models.Booking, error) {
	tech, err := s.techRepo.GetByUserID(ctx, technicianUserID)
	if err != nil {
		return nil, err
	}
	if tech == nil {
		return nil, errors.New("technician profile not found")
	}

	detail, err := s.GetDetail(ctx, bookingID)
	if err != nil {
		return nil, err
	}
	if detail == nil {
		return nil, errors.New("booking not found")
	}
	b := &detail.Booking
	if b.TechnicianID == nil || *b.TechnicianID != tech.ID {
		return nil, errors.New("you are not assigned to this booking")
	}
	switch b.Status {
	case models.BookingAccepted, models.BookingOnTheWay, models.BookingArrived, models.BookingInspecting, models.BookingInProgress:
		// ok — an active, ongoing booking
	default:
		return nil, errors.New("a call can only be started while the job is active")
	}

	if s.fcm != nil {
		technicianName := "Your technician"
		if detail.Technician != nil && detail.Technician.Name != "" {
			technicianName = detail.Technician.Name
		}
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Incoming call",
			technicianName+" is calling you about your booking.",
			map[string]string{
				"type":            "booking_call_incoming",
				"booking_id":      bookingID,
				"technician_name": technicianName,
				"call_type":       "audio",
			})
	}
	return b, nil
}

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

func (s *BookingService) RepeatCustomers(ctx context.Context, technicianID string) ([]models.RepeatCustomer, error) {
	return s.bookingRepo.ListRepeatCustomersByTechnician(ctx, technicianID)
}

func (s *BookingService) RepeatTechnicians(ctx context.Context, customerID string) ([]models.RepeatTechnician, error) {
	return s.bookingRepo.ListRepeatTechniciansByCustomer(ctx, customerID)
}

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
			// sender_name lets the recipient's app open straight into this
			// chat thread with the right AppBar title on tap, without an
			// extra round trip before the screen can render (see
			// NotificationDetailScreen / app.dart's onNotificationTap).
			senderName := ""
			if sender, err := s.userRepo.GetByID(ctx, userID); err == nil && sender != nil {
				senderName = sender.Name
			}
			_ = s.fcm.SendToUser(ctx, recipientID, "New message",
				content, map[string]string{"booking_id": bookingID, "type": "booking_message", "sender_name": senderName})
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

func generateOTP() string {
	n := time.Now().UnixNano() % 10000
	if n < 0 {
		n = -n
	}
	return fmt.Sprintf("%04d", n)
}

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

func (s *BookingService) GetOTP(ctx context.Context, bookingID string) (string, error) {
	return s.bookingRepo.GetOTP(ctx, bookingID)
}

func (s *BookingService) TechnicianLocation(ctx context.Context, bookingID string) (lat, lng *float64, updatedAt *time.Time, err error) {
	return s.bookingRepo.TechnicianLocationForBooking(ctx, bookingID)
}

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
		return s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingInProgress, "Customer approved estimate")
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