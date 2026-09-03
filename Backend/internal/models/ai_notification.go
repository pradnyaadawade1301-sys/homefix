package models

import "time"

type AIDiagnosisSession struct {
	ID         string    `json:"id"`
	UserID     string    `json:"user_id"`
	BookingID  *string   `json:"booking_id,omitempty"`
	CategoryID *string   `json:"category_id,omitempty"`
	Status     string    `json:"status"`
	CreatedAt  time.Time `json:"created_at"`
}

type AIDiagnosisMessage struct {
	ID        string    `json:"id"`
	SessionID string    `json:"session_id"`
	Role      string    `json:"role"` // user | assistant
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

// AIDiagnosisResult is the structured diagnosis parsed from the Groq model's
// JSON response. Sent back to the Flutter app alongside the raw assistant
// reply so the UI can render a diagnosis card (fault, causes, confidence,
// cost/time estimates, remote-vs-onsite recommendation).
type AIDiagnosisResult struct {
	PossibleFault        string   `json:"possible_fault"`
	Causes               []string `json:"causes"`
	FollowUpQuestions    []string `json:"follow_up_questions"`
	ConfidenceScore      float64  `json:"confidence_score"` // 0-100
	EstimatedCostMin     float64  `json:"estimated_cost_min"`
	EstimatedCostMax     float64  `json:"estimated_cost_max"`
	EstimatedTimeMinutes int      `json:"estimated_time_minutes"`
	CanSolveRemotely     bool     `json:"can_solve_remotely"`
	Recommendation       string   `json:"recommendation"` // "remote" or "onsite"
}

type Notification struct {
	ID         string                 `json:"id"`
	UserID     string                 `json:"user_id"`
	Title      string                 `json:"title"`
	Body       string                 `json:"body"`
	Data       map[string]interface{} `json:"data,omitempty"`
	IsRead     bool                   `json:"is_read"`
	SentViaFCM bool                   `json:"sent_via_fcm"`
	CreatedAt  time.Time              `json:"created_at"`
}