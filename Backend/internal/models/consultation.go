package models

import "time"

// Consultation is an on-demand, peer-to-peer live video call between a customer and
// whichever technician the backend matches them with — no home visit required unless
// the technician later recommends one (see EscalatedBookingID).
type Consultation struct {
	ID                 string     `json:"id"`
	CustomerID         string     `json:"customer_id"`
	TechnicianID       *string    `json:"technician_id,omitempty"`
	CategoryID         string     `json:"category_id"`
	Status             string     `json:"status"` // searching, ringing, accepted, rejected, no_technician, in_call, ended
	Fee                float64    `json:"fee"`
	DurationSeconds    *int       `json:"duration_seconds,omitempty"`
	PaymentStatus      string     `json:"payment_status"` // pending, paid, not_required
	EscalatedBookingID *string    `json:"escalated_booking_id,omitempty"`
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
