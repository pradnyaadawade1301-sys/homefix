package models

import "time"

// --- Disputes ---

const (
	DisputeOpen             = "open"
	DisputeUnderReview      = "under_review"
	DisputeResolvedRefund   = "resolved_refund"
	DisputeResolvedRejected = "resolved_rejected"
	DisputeResolvedPartial  = "resolved_partial"
)

type Dispute struct {
	ID             string     `json:"id"`
	BookingID      *string    `json:"booking_id,omitempty"`
	ConsultationID *string    `json:"consultation_id,omitempty"`
	RaisedBy       string     `json:"raised_by"`
	Reason         string     `json:"reason"`
	Status         string     `json:"status"`
	RefundAmount   *float64   `json:"refund_amount,omitempty"`
	AdminNotes     *string    `json:"admin_notes,omitempty"`
	ResolvedBy     *string    `json:"resolved_by,omitempty"`
	ResolvedAt     *time.Time `json:"resolved_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`

	// Joined display fields
	RaisedByName string `json:"raised_by_name,omitempty"`
}

type DisputeEvidence struct {
	ID         string    `json:"id"`
	DisputeID  string    `json:"dispute_id"`
	UploadedBy string    `json:"uploaded_by"`
	FileURL    string    `json:"file_url"`
	Note       string    `json:"note,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

// --- Inventory ---

type Supplier struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	ContactPerson string    `json:"contact_person,omitempty"`
	Phone         string    `json:"phone,omitempty"`
	Email         string    `json:"email,omitempty"`
	Address       string    `json:"address,omitempty"`
	IsActive      bool      `json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
}

type SparePart struct {
	ID            string    `json:"id"`
	CategoryID    *string   `json:"category_id,omitempty"`
	SupplierID    *string   `json:"supplier_id,omitempty"`
	Name          string    `json:"name"`
	SKU           *string   `json:"sku,omitempty"`
	Description   string    `json:"description,omitempty"`
	UnitPrice     float64   `json:"unit_price"`
	StockQuantity int       `json:"stock_quantity"`
	ReorderLevel  int       `json:"reorder_level"`
	IsActive      bool      `json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type StockMovement struct {
	ID            string    `json:"id"`
	SparePartID   string    `json:"spare_part_id"`
	ChangeType    string    `json:"change_type"` // restock | usage | adjustment
	QuantityDelta int       `json:"quantity_delta"`
	BookingID     *string   `json:"booking_id,omitempty"`
	Note          string    `json:"note,omitempty"`
	CreatedBy     *string   `json:"created_by,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

type SparePartOrder struct {
	ID          string     `json:"id"`
	SparePartID string     `json:"spare_part_id"`
	SupplierID  *string    `json:"supplier_id,omitempty"`
	Quantity    int        `json:"quantity"`
	UnitCost    float64    `json:"unit_cost"`
	Status      string     `json:"status"` // ordered | received | cancelled
	OrderedBy   *string    `json:"ordered_by,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	ReceivedAt  *time.Time `json:"received_at,omitempty"`
}

// --- CMS ---

type CmsPage struct {
	ID        string    `json:"id"`
	Key       string    `json:"key"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	UpdatedBy *string   `json:"updated_by,omitempty"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CmsFaq struct {
	ID        string    `json:"id"`
	Question  string    `json:"question"`
	Answer    string    `json:"answer"`
	SortOrder int       `json:"sort_order"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
}

type CmsAnnouncement struct {
	ID        string     `json:"id"`
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	IsActive  bool       `json:"is_active"`
	StartsAt  *time.Time `json:"starts_at,omitempty"`
	EndsAt    *time.Time `json:"ends_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

type CmsBanner struct {
	ID        string    `json:"id"`
	Title     string    `json:"title,omitempty"`
	ImageURL  string    `json:"image_url"`
	LinkURL   string    `json:"link_url,omitempty"`
	SortOrder int       `json:"sort_order"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
}

// --- Audit log ---

type AuditLog struct {
	ID          string    `json:"id"`
	AdminUserID string    `json:"admin_user_id"`
	Action      string    `json:"action"`
	EntityType  string    `json:"entity_type"`
	EntityID    string    `json:"entity_id,omitempty"`
	Details     string    `json:"details,omitempty"` // raw JSON text
	IPAddress   string    `json:"ip_address,omitempty"`
	CreatedAt   time.Time `json:"created_at"`

	AdminName string `json:"admin_name,omitempty"`
}

// --- Analytics ---

type RevenueSummary struct {
	TotalRevenue       float64 `json:"total_revenue"`
	PlatformCommission float64 `json:"platform_commission"`
	TechnicianPayouts  float64 `json:"technician_payouts"`
	PaidBookingsCount  int     `json:"paid_bookings_count"`
	RefundedAmount     float64 `json:"refunded_amount"`
}

type DailyMetric struct {
	Date  string  `json:"date"`
	Value float64 `json:"value"`
}

type DashboardStats struct {
	TotalCustomers           int     `json:"total_customers"`
	TotalTechnicians         int     `json:"total_technicians"`
	PendingTechnicianKyc     int     `json:"pending_technician_kyc"`
	TotalBookings            int     `json:"total_bookings"`
	BookingsToday            int     `json:"bookings_today"`
	OpenDisputes             int     `json:"open_disputes"`
	TotalRevenue             float64 `json:"total_revenue"`
	RevenueToday             float64 `json:"revenue_today"`
	AiSessionsTotal          int     `json:"ai_sessions_total"`
	ConsultationToBookingPct float64 `json:"consultation_to_booking_pct"`
}
