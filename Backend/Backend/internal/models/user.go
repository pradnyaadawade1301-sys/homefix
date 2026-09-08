package models

import "time"

type User struct {
	ID           string     `json:"id"`
	Phone        string     `json:"phone"`
	Name         string     `json:"name"`
	Email        *string    `json:"email,omitempty"`
	PasswordHash string     `json:"-"`
	Role         string     `json:"role"`
	OTPCode      *string    `json:"-"`
	OTPExpiresAt *time.Time `json:"-"`
	// EmailOTPCode/EmailOTPExpiresAt are separate from OTPCode/OTPExpiresAt
	// (phone OTP) so requesting one kind of OTP doesn't invalidate the other —
	// see 016_email_otp_columns.sql.
	EmailOTPCode      *string    `json:"-"`
	EmailOTPExpiresAt *time.Time `json:"-"`
	PhoneVerified     bool       `json:"phone_verified"`
	EmailVerified     bool       `json:"email_verified"`
	PhotoURL          *string    `json:"photo_url,omitempty"`
	GoogleID          *string    `json:"-"`
	FCMToken          *string    `json:"-"`
	IsActive          bool       `json:"is_active"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type Address struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Label     string    `json:"label"`
	Line1     string    `json:"line1"`
	Line2     string    `json:"line2,omitempty"`
	City      string    `json:"city"`
	State     string    `json:"state"`
	Pincode   string    `json:"pincode"`
	Latitude  *float64  `json:"latitude,omitempty"`
	Longitude *float64  `json:"longitude,omitempty"`
	IsDefault bool      `json:"is_default"`
	CreatedAt time.Time `json:"created_at"`
}