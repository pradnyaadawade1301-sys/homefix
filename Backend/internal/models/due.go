package models

import "time"

// Due is the platform commission a technician owes after collecting cash.
type Due struct {
	ID        string     `json:"id"`
	PaymentID string     `json:"payment_id"`
	BookingID *string    `json:"booking_id"`
	Amount    float64    `json:"amount"`
	Status    string     `json:"status"` // "pending" | "paid"
	CreatedAt time.Time  `json:"created_at"`
	PaidAt    *time.Time `json:"paid_at"`
}

type DueSummary struct {
	PendingTotal  float64    `json:"pending_total"`
	Limit         float64    `json:"limit"`
	MaxDays       int        `json:"max_days"`
	CodBlocked    bool       `json:"cod_blocked"`
	BlockedReason string     `json:"blocked_reason"`
	OldestDueAt   *time.Time `json:"oldest_due_at"`
	Dues          []Due      `json:"dues"`
}
