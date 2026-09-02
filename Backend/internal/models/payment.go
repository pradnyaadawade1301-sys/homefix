package models

import "time"

const (
	PaymentCreated  = "created"
	PaymentPaid     = "paid"
	PaymentFailed   = "failed"
	PaymentRefunded = "refunded"
)

// Payment "type" — see migration 022_visit_fee.sql. PaymentTypeService is the
// normal final-invoice payment (default, unchanged for every existing row);
// PaymentTypeVisitFee is the ₹99 pre-visit inspection charge.
const (
	PaymentTypeService  = "service"
	PaymentTypeVisitFee = "visit_fee"
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
	CgstAmount         *float64   `json:"cgst_amount,omitempty"` // half of gst_amount — India intra-state GST split
	SgstAmount         *float64   `json:"sgst_amount,omitempty"` // the other half
	Currency           string     `json:"currency"`
	Method             *string    `json:"method,omitempty"`
	Status             string     `json:"status"`
	UpiStatus          *string    `json:"upi_status,omitempty"` // raw status the UPI app itself returned
	UpiResponseCode    *string    `json:"upi_response_code,omitempty"`
	UpiApprovalRef     *string    `json:"upi_approval_ref,omitempty"`
	Verified           bool       `json:"verified"` // true only once payment was actually verified paid
	IsRepeatCustomer   bool       `json:"is_repeat_customer"`
	RepeatDiscountPercent *float64 `json:"repeat_discount_percent,omitempty"`
	RepeatDiscountAmount  *float64 `json:"repeat_discount_amount,omitempty"`
	// Razorpay identifiers — see internal/service/razorpay_service.go. Set once
	// the app hands back Checkout's response and the backend has independently
	// re-verified the signature server-side.
	RazorpayOrderID    *string    `json:"razorpay_order_id,omitempty"`
	RazorpayPaymentID  *string    `json:"razorpay_payment_id,omitempty"`
	RazorpaySignature  *string    `json:"razorpay_signature,omitempty"`
	PlatformCommission *float64   `json:"platform_commission,omitempty"`
	TechnicianEarning  *float64   `json:"technician_earning,omitempty"`
	// PaymentType distinguishes the ₹99 visit-fee charge from the normal final
	// service payment (default "service" for every pre-existing row).
	PaymentType     string   `json:"payment_type"`
	VisitFeeCredit  *float64 `json:"visit_fee_credit,omitempty"` // set only on a "service" payment that credited back an already-paid visit fee
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

// InvoiceDetail is the full GST-compliant invoice for one payment — everything
// the invoice screen/PDF needs in a single response, so the client never has to
// stitch together booking/category/customer/technician calls itself. See
// PaymentRepository.GetInvoiceDetail (the only place this is populated) and
// PaymentHandler.GetInvoice.
type InvoiceDetail struct {
	Payment           Payment `json:"payment"`
	InvoiceNumber     string  `json:"invoice_number"`
	ServiceCode       string  `json:"service_code"`
	BookingID         string  `json:"booking_id"`
	CategoryName      string  `json:"category_name"`
	ProblemDescription string `json:"problem_description,omitempty"`
	CustomerName      string  `json:"customer_name"`
	CustomerPhone     string  `json:"customer_phone"`
	TechnicianName    string  `json:"technician_name,omitempty"`
	TechnicianPhone   string  `json:"technician_phone,omitempty"`
	AddressFormatted  string  `json:"address_formatted,omitempty"`
	PaidAt            time.Time `json:"paid_at"`

	// Line-item breakdown, all derived from Payment but flattened here so the
	// invoice template doesn't need to null-check pointer fields everywhere.
	BaseAmount  float64 `json:"base_amount"`
	CgstPercent float64 `json:"cgst_percent"` // half of Payment.GstPercent
	CgstAmount  float64 `json:"cgst_amount"`
	SgstPercent float64 `json:"sgst_percent"` // the other half
	SgstAmount  float64 `json:"sgst_amount"`
	VisitFeeCredit *float64 `json:"visit_fee_credit,omitempty"` // already-paid ₹99 visit fee, deducted from this total
	TotalAmount float64 `json:"total_amount"`

	IsRepeatCustomer      bool     `json:"is_repeat_customer"`
	RepeatDiscountPercent *float64 `json:"repeat_discount_percent,omitempty"`
	RepeatDiscountAmount  *float64 `json:"repeat_discount_amount,omitempty"`
}