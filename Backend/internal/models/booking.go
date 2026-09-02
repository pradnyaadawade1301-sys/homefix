package models

import "time"

const (
	BookingRequested  = "requested"
	BookingAccepted   = "accepted"
	BookingInProgress = "in_progress"
	BookingCompleted  = "completed"
	BookingCancelled  = "cancelled"

	// Granular on-site sub-steps shown on the customer's live tracking
	// screen between "accepted" and "in_progress"/"completed". These are
	// stored in the same free-form bookings.status column (see
	// migration 017) — no schema change needed, just new recognised values.
	BookingOnTheWay         = "on_the_way"
	BookingArrived          = "arrived"
	BookingInspecting       = "inspecting"
	BookingRepairInProgress = "repair_in_progress"
)

// Visit-fee status values — see migration 022_visit_fee.sql. A booking created
// directly (not via consultation escalation) is "not_required" and skips the
// visit-fee gate entirely.
const (
	VisitFeeNotRequired = "not_required"
	VisitFeePending     = "pending"
	VisitFeePaid        = "paid"
	VisitFeeRefunded    = "refunded"
)

// DefaultVisitFeeAmount is the fixed ₹99 pre-visit inspection charge applied
// when a Live Video Consultation is escalated into an on-site booking.
const DefaultVisitFeeAmount = 99.0

// ValidBookingStatuses is the whitelist enforced by BookingService.UpdateStatus
// so a typo'd status string can't get silently stuck in a booking's history.
var ValidBookingStatuses = map[string]bool{
	BookingRequested:        true,
	BookingAccepted:         true,
	BookingOnTheWay:         true,
	BookingArrived:          true,
	BookingInspecting:       true,
	BookingRepairInProgress: true,
	BookingInProgress:       true,
	BookingCompleted:        true,
	BookingCancelled:        true,
}

type Booking struct {
	ID                 string     `json:"id"`
	CustomerID         string     `json:"customer_id"`
	TechnicianID       *string    `json:"technician_id,omitempty"`
	CategoryID         string     `json:"category_id"`
	AddressID          string     `json:"address_id"`
	Status             string     `json:"status"`
	ServiceCode        string     `json:"service_code,omitempty"` // e.g. "SRV-001042" — a stable, human-readable ID for invoices/receipts, distinct from the internal UUID
	PaymentStatus      string     `json:"payment_status"`         // pending | paid | refunded — set only via verified UpiService.ConfirmPayment
	ProblemDescription string     `json:"problem_description,omitempty"`
	Notes              *string    `json:"notes,omitempty"`
	Images             []string   `json:"images,omitempty"`
	ScheduledAt        *time.Time `json:"scheduled_at,omitempty"`
	EstimatedPrice     *float64   `json:"estimated_price,omitempty"`
	FinalPrice         *float64   `json:"final_price,omitempty"`
	// OTPCode is the arrival OTP the customer reads out to the technician. It's
	// tagged json:"-" (never auto-serialized) because this same struct backs
	// both the customer's and the technician's booking views — the handler
	// explicitly copies it onto the response only for the customer, keeping
	// it hidden from the technician's side.
	OTPCode       *string    `json:"otp_code,omitempty"`
	OTPVerifiedAt *time.Time `json:"otp_verified_at,omitempty"` // set once the technician has confirmed the customer's OTP on-site
	// VisitFeeAmount/VisitFeeStatus gate the "on_the_way" transition when the
	// booking came from a consultation escalation — see migration
	// 022_visit_fee.sql and BookingService.UpdateStatus.
	VisitFeeAmount *float64 `json:"visit_fee_amount,omitempty"`
	VisitFeeStatus string   `json:"visit_fee_status"`
	// --- Warranty (see migration 022) ---
	// WarrantyEnabled/WarrantyDays/WarrantyExpiresAt are set once, at
	// completion, by BookingService.Complete — WarrantyDays is validated
	// there against the category's allowed options, so this is never an
	// arbitrary technician-typed number.
	WarrantyEnabled   bool       `json:"warranty_enabled"`
	WarrantyDays      *int       `json:"warranty_days,omitempty"`
	WarrantyExpiresAt *time.Time `json:"warranty_expires_at,omitempty"`
	// IsWarrantyClaim/WarrantyClaimOf mark this booking as itself a warranty
	// claim raised against an earlier, completed booking (see
	// BookingService.RaiseWarrantyClaim) — otherwise both are zero-valued.
	IsWarrantyClaim bool      `json:"is_warranty_claim"`
	WarrantyClaimOf *string   `json:"warranty_claim_of,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// BookingEstimateItem is a single line in a service estimate, e.g.
// "AC Gas Refill — ₹1,500".
type BookingEstimateItem struct {
	ID          string  `json:"id"`
	Description string  `json:"description"`
	Amount      float64 `json:"amount"`
}

// BookingEstimate is the itemised quote a technician raises after
// inspecting the problem on-site. The customer must explicitly Approve it
// (or ask to Discuss / Decline) before the technician can start any paid
// repair work — see BookingService.RespondToEstimate.
type BookingEstimate struct {
	ID        string                `json:"id"`
	BookingID string                `json:"booking_id"`
	Status    string                `json:"status"` // pending | approved | declined
	Total     float64               `json:"total"`
	Note      string                `json:"note,omitempty"`
	Items     []BookingEstimateItem `json:"items"`
	CreatedAt time.Time             `json:"created_at"`
	UpdatedAt time.Time             `json:"updated_at"`
}

const (
	EstimatePending  = "pending"
	EstimateApproved = "approved"
	EstimateDeclined = "declined"
)

// BookingServicePhoto is a single before/after photo the technician attaches
// while the repair is in progress.
type BookingServicePhoto struct {
	ID        string    `json:"id"`
	BookingID string    `json:"booking_id"`
	PhotoURL  string    `json:"photo_url"`
	PhotoType string    `json:"photo_type"` // before | after
	CreatedAt time.Time `json:"created_at"`
}

// BookingMessage is a single chat message between the customer and the
// technician assigned to a booking. sender_role tells the UI which side to
// render it on without needing an extra join.
type BookingMessage struct {
	ID         string    `json:"id"`
	BookingID  string    `json:"booking_id"`
	SenderID   string    `json:"sender_id"`
	SenderRole string    `json:"sender_role"` // "customer" | "technician" | "admin"
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
	// WarrantyClaimOfServiceCode is the human-readable service code (e.g.
	// "SRV-001042") of the original booking this one is a warranty claim
	// against — set only when Booking.IsWarrantyClaim is true. Lets the UI
	// show "Warranty claim for SRV-001042" without a second lookup.
	WarrantyClaimOfServiceCode *string `json:"warranty_claim_of_service_code,omitempty"`
}

type BookingStatusHistory struct {
	ID        string    `json:"id"`
	BookingID string    `json:"booking_id"`
	Status    string    `json:"status"`
	Note      string    `json:"note,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// ServiceHistoryPayment is a slimmed-down view of a booking's payment — just enough
// to show what was paid and whether a repeat-customer discount applied — for the
// technician's per-customer Service History screen.
type ServiceHistoryPayment struct {
	Amount                float64  `json:"amount"`
	Status                string   `json:"status"`
	IsRepeatCustomer      bool     `json:"is_repeat_customer"`
	RepeatDiscountPercent *float64 `json:"repeat_discount_percent,omitempty"`
	RepeatDiscountAmount  *float64 `json:"repeat_discount_amount,omitempty"`
}

// ServiceHistoryEntry is one past booking between a specific customer and
// technician, with its payment/pricing-tier info attached (nil if never paid) —
// powers GET /technicians/:id/customers/:customerId/history.
type ServiceHistoryEntry struct {
	BookingDetail
	Payment *ServiceHistoryPayment `json:"payment,omitempty"`
}
