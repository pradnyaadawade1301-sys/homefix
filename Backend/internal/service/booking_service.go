package service

import (
	"context"
	"errors"
	"fmt"

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

	if err := s.bookingRepo.AssignTechnician(ctx, bookingID, technicianID); err != nil {
		return err
	}

	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Technician assigned",
			"A technician has accepted your booking and is on the way.",
			map[string]string{"booking_id": bookingID, "type": "booking_accepted"})
	}
	return nil
}

func (s *BookingService) UpdateStatus(ctx context.Context, bookingID, status, note string) error {
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
	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Booking update",
			"Your booking status changed to "+status, map[string]string{"booking_id": bookingID, "type": "booking_status"})
	}
	return nil
}

// Complete records the technician's final_price — this IS the invoice, since
// it's the only number the app ever asks the customer to pay (see
// UpiService.CreateOrder, which validates the payment amount against it). The
// FCM push here is the only signal the customer gets that a bill is ready;
// without it they'd only find out by happening to reopen the booking.
func (s *BookingService) Complete(ctx context.Context, bookingID string, finalPrice float64) error {
	b, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return err
	}
	if b == nil {
		return errors.New("booking not found")
	}

	if err := s.bookingRepo.SetFinalPrice(ctx, bookingID, finalPrice); err != nil {
		return err
	}
	if err := s.bookingRepo.UpdateStatus(ctx, bookingID, models.BookingCompleted, "Job completed"); err != nil {
		return err
	}

	if s.fcm != nil {
		_ = s.fcm.SendToUser(ctx, b.CustomerID, "Invoice ready",
			fmt.Sprintf("Your technician has completed the job. Amount due: \u20b9%.2f. Tap to pay.", finalPrice),
			map[string]string{"booking_id": bookingID, "type": "invoice_ready", "final_price": fmt.Sprintf("%.2f", finalPrice)})
	}
	return nil
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
// support purposes, recorded as "technician" side.
func (s *BookingService) resolveBookingParticipantRole(ctx context.Context, b *models.Booking, userID, userRole string) (string, error) {
	if userID == b.CustomerID {
		return "customer", nil
	}
	if userRole == "admin" {
		return "technician", nil
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
