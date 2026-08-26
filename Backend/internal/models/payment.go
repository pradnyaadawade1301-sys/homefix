package models

import "time"

const (
	PaymentCreated  = "created"
	PaymentPaid     = "paid"
	PaymentFailed   = "failed"
	PaymentRefunded = "refunded"
)

type Payment struct {
	ID                 string     `json:"id"`
	BookingID          string     `json:"booking_id"`
	UserID             string     `json:"user_id"`
	TransactionRef     string     `json:"transaction_ref"`
	UpiTxnID           *string    `json:"upi_txn_id,omitempty"`
	InvoiceNumber      *string    `json:"invoice_number,omitempty"`
	Amount             float64    `json:"amount"`
	BaseAmount         *float64   `json:"base_amount,omitempty"`
	GstAmount          *float64   `json:"gst_amount,omitempty"`
	GstPercent         *float64   `json:"gst_percent,omitempty"`
	Currency           string     `json:"currency"`
	Method             *string    `json:"method,omitempty"`
	Status             string     `json:"status"`
	UpiStatus          *string    `json:"upi_status,omitempty"` // raw status the UPI app itself returned
	UpiResponseCode    *string    `json:"upi_response_code,omitempty"`
	UpiApprovalRef     *string    `json:"upi_approval_ref,omitempty"`
	Verified           bool       `json:"verified"` // true only once the UPI app reported SUCCESS
	PlatformCommission *float64   `json:"platform_commission,omitempty"`
	TechnicianEarning  *float64   `json:"technician_earning,omitempty"`
	RefundedAt         *time.Time `json:"refunded_at,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type Wallet struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Balance   float64   `json:"balance"`
	UpdatedAt time.Time `json:"updated_at"`
}

type WalletTransaction struct {
	ID          string    `json:"id"`
	WalletID    string    `json:"wallet_id"`
	Type        string    `json:"type"` // credit | debit
	Amount      float64   `json:"amount"`
	Reason      string    `json:"reason,omitempty"`
	ReferenceID *string   `json:"reference_id,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type Review struct {
	ID           string    `json:"id"`
	BookingID    string    `json:"booking_id"`
	CustomerID   string    `json:"customer_id"`
	TechnicianID string    `json:"technician_id"`
	Rating       int       `json:"rating"`
	Comment      string    `json:"comment,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}
