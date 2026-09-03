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
	ID                 string  `json:"id"`
	CustomerID         string  `json:"customer_id"`
	TechnicianID       *string `json:"technician_id,omitempty"`
	CategoryID         string  `json:"category_id"`
	Status             string  `json:"status"` // scheduled, confirmed, searching, ringing, accepted, rejected, no_technician, in_call, ended, cancelled
	Fee                float64 `json:"fee"`
	DurationSeconds    *int    `json:"duration_seconds,omitempty"`
	PaymentStatus      string  `json:"payment_status"` // pending, paid, not_required
	EscalatedBookingID *string `json:"escalated_booking_id,omitempty"`
	// DeclineReason is set when a technician declines a scheduled slot (or
	// rejects an instant request) and explains why — surfaced to the customer
	// so "declined" isn't a dead end with no context. Nil for every other status.
	DeclineReason *string `json:"decline_reason,omitempty"`

	// Post-call recommendation — set by ConsultationService.RecommendOnsite
	// once the technician sends their simple problem+price summary after the
	// call ends. RecommendationStatus is nil until a recommendation is sent,
	// then "pending" -> "accepted" (via Escalate) or "declined".
	RecommendationSummary *string    `json:"recommendation_summary,omitempty"`
	RecommendationPrice   *float64   `json:"recommendation_price,omitempty"`
	RecommendationStatus  *string    `json:"recommendation_status,omitempty"`
	RecommendationSentAt  *time.Time `json:"recommendation_sent_at,omitempty"`

	ScheduledAt *time.Time `json:"scheduled_at,omitempty"` // nil = instant ("Consult Now")
	StartedAt   *time.Time `json:"started_at,omitempty"`
	EndedAt     *time.Time `json:"ended_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`

	// Request-time details — collected once, up front, when the customer
	// requests the call (see migrations/027_consultation_request_details.sql),
	// so the technician has real context before answering instead of finding
	// out what the problem even is only after picking up.
	//
	// Note is the customer's one-line description of the issue — kept
	// separate from RecommendationSummary (the technician's own post-call
	// note) so the two directions never overwrite each other.
	Note *string `json:"note,omitempty"`
	// Area is a short, privacy-friendly location hint (e.g. "Andheri West,
	// Mumbai") — NOT a full address. A video consultation is remote by
	// definition; this exists purely so the technician knows roughly where
	// the customer is, in case the call later escalates to an on-site visit
	// (see RecommendOnsite/Escalate) and service-area coverage matters.
	Area *string `json:"area,omitempty"`
	// AIDiagnosisSessionID links back to an AI diagnosis chat the customer
	// already ran (see ai_diagnosis_sessions/ai_diagnosis_messages) before
	// requesting this call — optional; nil if they skipped straight to a
	// video call without using AI diagnosis first.
	AIDiagnosisSessionID *string `json:"ai_diagnosis_session_id,omitempty"`
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
	// AIAssessment is NOT a database column — it's the last AI-authored
	// message from the linked ai_diagnosis_sessions chat (see
	// AIDiagnosisSessionID above), resolved and attached by
	// ConsultationService.attachAIAssessment right before returning to the
	// technician. Nil whenever AIDiagnosisSessionID is nil, or the linked
	// session turns out to have no AI messages yet.
	AIAssessment *string `json:"ai_assessment,omitempty"`
}
