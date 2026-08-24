package models

import "time"

type Category struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	IconURL     string    `json:"icon_url,omitempty"`
	BasePrice   float64   `json:"base_price"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
}

// TechnicianPublic is the customer-facing shape returned by the public browse/detail
// endpoints — joins in the technician's name (from users) and service category name,
// and omits internal fields (exact lat/lng, raw ids the UI doesn't need).
type TechnicianPublic struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	CategoryID      string    `json:"category_id"`
	CategoryName    string    `json:"category_name"`
	ExperienceYears int       `json:"experience_years"`
	RatingAvg       float64   `json:"rating_avg"`
	RatingCount     int       `json:"rating_count"`
	IsVerified      bool      `json:"is_verified"`
	IsAvailable     bool      `json:"is_available"`
	CreatedAt       time.Time `json:"created_at"`
}

// TechnicianNearby is the shape returned by the "find available technicians" endpoint
// used by the customer-facing nearby/tracking screen — joins in name + category name
// (like TechnicianPublic) but also carries live lat/lng and distance from the customer,
// since that's the whole point of this endpoint.
type TechnicianNearby struct {
	ID              string   `json:"id"`
	Name            string   `json:"name"`
	CategoryID      string   `json:"category_id"`
	CategoryName    string   `json:"category_name"`
	ExperienceYears int      `json:"experience_years"`
	RatingAvg       float64  `json:"rating_avg"`
	RatingCount     int      `json:"rating_count"`
	IsAvailable     bool     `json:"is_available"`
	CurrentLat      *float64 `json:"current_lat,omitempty"`
	CurrentLng      *float64 `json:"current_lng,omitempty"`
	// DistanceKm is nil when the caller didn't supply lat/lng (results are then sorted by rating instead).
	DistanceKm *float64 `json:"distance_km,omitempty"`
}

type Technician struct {
	ID              string `json:"id"`
	UserID          string `json:"user_id"`
	CategoryID      string `json:"category_id"`
	ExperienceYears int    `json:"experience_years"`
	Address         string `json:"address,omitempty"`
	GovernmentIDURL string `json:"government_id_url,omitempty"`
	ProfilePhotoURL string `json:"profile_photo_url,omitempty"`
	// ApprovalStatus is one of "pending", "approved", "rejected" — the source of truth
	// for admin approval. IsVerified is kept in sync for backward-compatible queries.
	ApprovalStatus  string    `json:"approval_status"`
	RejectionReason string    `json:"rejection_reason,omitempty"`
	RatingAvg       float64   `json:"rating_avg"`
	RatingCount     int       `json:"rating_count"`
	IsVerified      bool      `json:"is_verified"`
	IsAvailable     bool      `json:"is_available"`
	CurrentLat      *float64  `json:"current_lat,omitempty"`
	CurrentLng      *float64  `json:"current_lng,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// TechnicianWithUser adds the user's own name/phone and the category's display
// name — used by the admin panel's Technician Approval queue, which needs to show
// who's asking (and their KYC documents) without a separate lookup per row.
type TechnicianWithUser struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	Name            string    `json:"name"`
	Phone           string    `json:"phone"`
	CategoryID      string    `json:"category_id"`
	CategoryName    string    `json:"category_name"`
	ExperienceYears int       `json:"experience_years"`
	Address         string    `json:"address,omitempty"`
	GovernmentIDURL string    `json:"government_id_url,omitempty"`
	ProfilePhotoURL string    `json:"profile_photo_url,omitempty"`
	ApprovalStatus  string    `json:"approval_status"`
	RejectionReason string    `json:"rejection_reason,omitempty"`
	RatingAvg       float64   `json:"rating_avg"`
	RatingCount     int       `json:"rating_count"`
	IsVerified      bool      `json:"is_verified"`
	IsAvailable     bool      `json:"is_available"`
	CreatedAt       time.Time `json:"created_at"`
}
