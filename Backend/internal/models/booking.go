package models

import "time"

const (
	BookingRequested  = "requested"
	BookingAccepted   = "accepted"
	BookingInProgress = "in_progress"
	BookingCompleted  = "completed"
	BookingCancelled  = "cancelled"
)

type Booking struct {
	ID                 string     `json:"id"`
	CustomerID         string     `json:"customer_id"`
	TechnicianID       *string    `json:"technician_id,omitempty"`
	CategoryID         string     `json:"category_id"`
	AddressID          string     `json:"address_id"`
	Status             string     `json:"status"`
	PaymentStatus      string     `json:"payment_status"` // pending | paid | refunded — set only via verified UpiService.ConfirmPayment
	ProblemDescription string     `json:"problem_description,omitempty"`
	Notes              *string    `json:"notes,omitempty"`
	Images             []string   `json:"images,omitempty"`
	ScheduledAt        *time.Time `json:"scheduled_at,omitempty"`
	EstimatedPrice     *float64   `json:"estimated_price,omitempty"`
	FinalPrice         *float64   `json:"final_price,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

// BookingMessage is a single chat message between the customer and the
// technician assigned to a booking. sender_role tells the UI which side to
// render it on without needing an extra join.
type BookingMessage struct {
	ID         string    `json:"id"`
	BookingID  string    `json:"booking_id"`
	SenderID   string    `json:"sender_id"`
	SenderRole string    `json:"sender_role"` // "customer" | "technician"
	Content    string    `json:"content"`
	CreatedAt  time.Time `json:"created_at"`
}

// --- Detailed / joined shapes used by the customer + technician "my bookings" screens ---
//
// A customer viewing their own bookings needs to see WHO the assigned technician is
// (name, phone, rating, experience). A technician viewing their assigned jobs needs to
// see WHO the customer is (name, phone) and where the job is (address). BookingDetail
// carries both, joined in a single query — Technician is nil until one is assigned;
// Customer is always present.

type BookingCustomerInfo struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Phone string `json:"phone"`
}

type BookingTechnicianInfo struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Phone           string  `json:"phone"`
	CategoryName    string  `json:"category_name"`
	ExperienceYears int     `json:"experience_years"`
	RatingAvg       float64 `json:"rating_avg"`
	RatingCount     int     `json:"rating_count"`
	IsVerified      bool    `json:"is_verified"`
}

type BookingAddressInfo struct {
	Label   string `json:"label"`
	Line1   string `json:"line1"`
	Line2   string `json:"line2,omitempty"`
	City    string `json:"city"`
	State   string `json:"state"`
	Pincode string `json:"pincode"`
}

// BookingDetail embeds Booking so all its JSON fields (id, customer_id, technician_id,
// status, problem_description, ...) stay at the top level, with the joined info added
// alongside.
type BookingDetail struct {
	Booking
	CategoryName string                 `json:"category_name"`
	Address      *BookingAddressInfo    `json:"address,omitempty"`
	Customer     *BookingCustomerInfo   `json:"customer,omitempty"`
	Technician   *BookingTechnicianInfo `json:"technician,omitempty"`
}

type BookingStatusHistory struct {
	ID        string    `json:"id"`
	BookingID string    `json:"booking_id"`
	Status    string    `json:"status"`
	Note      string    `json:"note,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}
