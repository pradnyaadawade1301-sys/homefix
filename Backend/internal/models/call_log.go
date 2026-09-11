package models

import "time"

const (
	CallLogRinging  = "ringing"
	CallLogReceived = "received"
	CallLogMissed   = "missed"
	CallLogRejected = "rejected"
)

// CallLog is one real audio-call attempt between a customer and a
// technician, with enough detail to render an actual phone-style call
// history: who called whom, when, and whether it was picked up.
type CallLog struct {
	ID              string     `json:"id"`
	BookingID       *string    `json:"booking_id,omitempty"`
	ConsultationID  *string    `json:"consultation_id,omitempty"`
	CallerUserID    string     `json:"caller_user_id"`
	CalleeUserID    string     `json:"callee_user_id"`
	Status          string     `json:"status"`
	StartedAt       time.Time  `json:"started_at"`
	AnsweredAt      *time.Time `json:"answered_at,omitempty"`
	EndedAt         *time.Time `json:"ended_at,omitempty"`
	DurationSeconds *int       `json:"duration_seconds,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

// CallLogEntry is CallLog joined with everything the app needs to render a
// single row: the other participant's name/role, and — from the viewing
// user's point of view — whether this was an outgoing or incoming call.
type CallLogEntry struct {
	CallLog
	PeerName       string `json:"peer_name"`
	PeerRole       string `json:"peer_role"` // "technician" or "customer"
	CategoryName   string `json:"category_name,omitempty"`
	IsOutgoing     bool   `json:"is_outgoing"` // true if the viewing user placed the call
}