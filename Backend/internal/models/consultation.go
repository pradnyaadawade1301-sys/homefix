package models

import "time"

// Consultation is an on-demand, peer-to-peer live video call between a customer and
// whichever technician the backend matches them with — no home visit required unless
// the technician later recommends one (see EscalatedBookingID).
//
// Two modes:
//   - Instant ("Consult Now"): ScheduledAt is nil. Flow unchanged —
//     searching -> ringing -> accepted -> in_call -> ended.
//   - Scheduled ("Schedule for later"): ScheduledAt is set to a future time.
//     The technician is NOT rung immediately; they see it as an upcoming request
//     and confirm/decline it ahead of time. Flow:
//     scheduled -> confirmed -> (at ScheduledAt) ringing -> accepted -> in_call -> ended.
//     The transition from confirmed -> ringing at the slot time is done by
//     ConsultationService.PromoteDueScheduled, polled periodically from main.go —
//     not client-triggered, so it fires even if neither app is in the foreground.
type Consultation struct {
	ID                 string     `json:"id"`
	CustomerID         string     `json:"customer_id"`
	TechnicianID       *string    `json:"technician_id,omitempty"`
	CategoryID         string     `json:"category_id"`
	Status             string     `json:"status"` // scheduled, confirmed, searching, ringing, accepted, rejected, no_technician, in_call, ended, cancelled
	Fee                float64    `json:"fee"`
	DurationSeconds    *int       `json:"duration_seconds,omitempty"`
	PaymentStatus      string     `json:"payment_status"` // pending, paid, not_required
	EscalatedBookingID *string    `json:"escalated_booking_id,omitempty"`
	ScheduledAt        *time.Time `json:"scheduled_at,omitempty"` // nil = instant ("Consult Now")
	StartedAt          *time.Time `json:"started_at,omitempty"`
	EndedAt            *time.Time `json:"ended_at,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

// ConsultationWithDetails adds the display info the app actually renders: which
// technician got matched (name/phone) and which category this is for — mirrors
// BookingWithDetails in booking.go for the same reason (one round trip, no N+1
// lookups on the client).
type ConsultationWithDetails struct {
	Consultation
	CategoryName    string `json:"category_name,omitempty"`
	CustomerName    string `json:"customer_name,omitempty"`
	CustomerPhone   string `json:"customer_phone,omitempty"`
	TechnicianName  string `json:"technician_name,omitempty"`
	TechnicianPhone string `json:"technician_phone,omitempty"`
}
