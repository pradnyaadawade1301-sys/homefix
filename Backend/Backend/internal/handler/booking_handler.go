package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/models"
	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type BookingHandler struct {
	bookingService *service.BookingService
}

func NewBookingHandler(bookingService *service.BookingService) *BookingHandler {
	return &BookingHandler{bookingService: bookingService}
}

type createBookingBody struct {
	CategoryID         string     `json:"category_id" binding:"required"`
	AddressID          string     `json:"address_id" binding:"required"`
	TechnicianID       *string    `json:"technician_id"`
	ProblemDescription string     `json:"problem_description"`
	Notes              *string    `json:"notes"`
	Images             []string   `json:"images"`
	ScheduledAt        *time.Time `json:"scheduled_at"`
}

func (h *BookingHandler) Create(c *gin.Context) {
	userID := c.GetString("user_id")
	var body createBookingBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	b := &models.Booking{
		CustomerID:         userID,
		CategoryID:         body.CategoryID,
		AddressID:          body.AddressID,
		ProblemDescription: body.ProblemDescription,
		Notes:              body.Notes,
		Images:             body.Images,
		ScheduledAt:        body.ScheduledAt,
	}
	var preferredTechnicianID string
	if body.TechnicianID != nil {
		preferredTechnicianID = *body.TechnicianID
	}
	created, err := h.bookingService.Create(c.Request.Context(), b, preferredTechnicianID)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, created)
}

func (h *BookingHandler) Get(c *gin.Context) {
	id := c.Param("id")
	b, err := h.bookingService.GetDetail(c.Request.Context(), id)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if b == nil {
		utils.Error(c, http.StatusNotFound, "booking not found")
		return
	}
	// otp_code is meant only for the customer to read out to the technician —
	// strip it out unless the requester is that booking's own customer.
	if userID := c.GetString("user_id"); userID != b.CustomerID {
		b.OTPCode = nil
	}
	utils.Success(c, http.StatusOK, b)
}

func (h *BookingHandler) MyBookings(c *gin.Context) {
	userID := c.GetString("user_id")
	list, err := h.bookingService.ListForCustomerDetailed(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}

func (h *BookingHandler) TechnicianBookings(c *gin.Context) {
	technicianID := c.Param("id")
	userID := c.GetString("user_id")
	userRole := c.GetString("role")
	if userRole != "admin" {
		owner, err := h.bookingService.TechnicianOwnedByUser(c.Request.Context(), technicianID, userID)
		if err != nil {
			utils.Error(c, http.StatusInternalServerError, err.Error())
			return
		}
		if !owner {
			utils.Error(c, http.StatusForbidden, "not authorized to view this technician's bookings")
			return
		}
	}
	list, err := h.bookingService.ListForTechnicianDetailed(c.Request.Context(), technicianID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	// otp_code is customer-only — never expose it on the technician's job list.
	for i := range list {
		list[i].OTPCode = nil
	}
	utils.Success(c, http.StatusOK, list)
}

// RepeatCustomers powers the technician's "My Customers" screen.
func (h *BookingHandler) RepeatCustomers(c *gin.Context) {
	technicianID := c.Param("id")
	list, err := h.bookingService.RepeatCustomers(c.Request.Context(), technicianID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if list == nil {
		list = []models.RepeatCustomer{}
	}
	utils.Success(c, http.StatusOK, list)
}

// RepeatTechnicians is the customer-side mirror of RepeatCustomers — powers the
// customer's "My Technicians" screen.
func (h *BookingHandler) RepeatTechnicians(c *gin.Context) {
	customerID := c.GetString("user_id")
	list, err := h.bookingService.RepeatTechnicians(c.Request.Context(), customerID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if list == nil {
		list = []models.RepeatTechnician{}
	}
	utils.Success(c, http.StatusOK, list)
}

// MyServiceHistoryWithTechnician is the customer-side mirror of ServiceHistory —
// every past booking the logged-in customer has made with a specific technician
// (date, work done/category, status, payment amount). Reached by tapping a
// technician on the customer's "My Technicians" screen.
func (h *BookingHandler) MyServiceHistoryWithTechnician(c *gin.Context) {
	customerID := c.GetString("user_id")
	technicianID := c.Param("technicianId")
	list, err := h.bookingService.ServiceHistory(c.Request.Context(), technicianID, customerID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if list == nil {
		list = []models.ServiceHistoryEntry{}
	}
	utils.Success(c, http.StatusOK, list)
}

// ServiceHistory returns a specific customer's past bookings with this
// technician, each with pricing/tier info — reached by tapping a customer on
// the technician's "My Customers" (repeat customers) screen.
func (h *BookingHandler) ServiceHistory(c *gin.Context) {
	technicianID := c.Param("id")
	customerID := c.Param("customerId")
	list, err := h.bookingService.ServiceHistory(c.Request.Context(), technicianID, customerID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if list == nil {
		list = []models.ServiceHistoryEntry{}
	}
	utils.Success(c, http.StatusOK, list)
}

type acceptBody struct {
	TechnicianID string `json:"technician_id" binding:"required"`
}

func (h *BookingHandler) Accept(c *gin.Context) {
	bookingID := c.Param("id")
	var body acceptBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.bookingService.Accept(c.Request.Context(), bookingID, body.TechnicianID); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "booking accepted"})
}

// Decline lets a technician turn down a booking that's been routed to them
// while it's still 'requested'. Mirrors Accept's request shape.
func (h *BookingHandler) Decline(c *gin.Context) {
	bookingID := c.Param("id")
	var body acceptBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.bookingService.Decline(c.Request.Context(), bookingID, body.TechnicianID); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "booking declined"})
}

type statusBody struct {
	Status string `json:"status" binding:"required"`
	Note   string `json:"note"`
}

func (h *BookingHandler) UpdateStatus(c *gin.Context) {
	bookingID := c.Param("id")
	var body statusBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.bookingService.UpdateStatus(c.Request.Context(), bookingID, body.Status, body.Note); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "status updated"})
}

// Arrived is a thin convenience wrapper around the same UpdateStatus path
// (status="arrived") so the technician app can call a dedicated, obviously-
// named endpoint instead of the generic /status route. It shares all the
// same logic — including the fresh-OTP generation in BookingService.UpdateStatus
// — so behaviour is identical to PATCH /bookings/:id/status {"status":"arrived"}.
type arrivedBody struct {
	TechnicianID string `json:"technician_id"`
}

func (h *BookingHandler) Arrived(c *gin.Context) {
	bookingID := c.Param("id")
	var body arrivedBody
	// technician_id is accepted for parity with other technician-action
	// endpoints (Accept, VerifyOTP) but UpdateStatus doesn't need it — the
	// booking is looked up by bookingID alone.
	_ = c.ShouldBindJSON(&body)
	if err := h.bookingService.UpdateStatus(c.Request.Context(), bookingID, models.BookingArrived, "Technician has arrived"); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "marked as arrived"})
}

type completeBody struct {
	FinalPrice float64 `json:"final_price" binding:"required"`
	// Warranty is optional and off by default — the technician must
	// explicitly opt in. WarrantyDays is only read/required when
	// WarrantyEnabled is true, and is validated server-side (see
	// BookingService.Complete) against the category's configured options.
	WarrantyEnabled bool `json:"warranty_enabled"`
	WarrantyDays    *int `json:"warranty_days"`
}

func (h *BookingHandler) Complete(c *gin.Context) {
	bookingID := c.Param("id")
	var body completeBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.bookingService.Complete(c.Request.Context(), bookingID, body.FinalPrice, body.WarrantyEnabled, body.WarrantyDays); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "booking completed"})
}

type warrantyClaimBody struct {
	Note string `json:"note"`
}

// RaiseWarrantyClaim - POST /bookings/:id/warranty-claim. Customer raises a
// claim against one of their own completed, still-under-warranty bookings —
// creates a brand-new linked booking (see BookingService.RaiseWarrantyClaim).
func (h *BookingHandler) RaiseWarrantyClaim(c *gin.Context) {
	userID := c.GetString("user_id")
	originalID := c.Param("id")
	var body warrantyClaimBody
	_ = c.ShouldBindJSON(&body)

	created, err := h.bookingService.RaiseWarrantyClaim(c.Request.Context(), userID, originalID, body.Note)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, created)
}

type cancelBody struct {
	Reason string `json:"reason"`
}

func (h *BookingHandler) Cancel(c *gin.Context) {
	bookingID := c.Param("id")
	var body cancelBody
	_ = c.ShouldBindJSON(&body)
	if err := h.bookingService.Cancel(c.Request.Context(), bookingID, body.Reason); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "booking cancelled"})
}

func (h *BookingHandler) History(c *gin.Context) {
	bookingID := c.Param("id")
	hist, err := h.bookingService.History(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, hist)
}

type bookingSendMessageBody struct {
	Content string `json:"content" binding:"required"`
}

// SendMessage — POST /bookings/:id/messages. Either the booking's customer
// or its assigned technician can post; role/participation is verified
// server-side in BookingService, not trusted from the client.
func (h *BookingHandler) SendMessage(c *gin.Context) {
	bookingID := c.Param("id")
	userID := c.GetString("user_id")
	userRole := c.GetString("role")

	var body bookingSendMessageBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	msg, err := h.bookingService.SendMessage(c.Request.Context(), bookingID, userID, userRole, body.Content)
	if err != nil {
		utils.Error(c, http.StatusForbidden, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, msg)
}

// ListMessages — GET /bookings/:id/messages
func (h *BookingHandler) ListMessages(c *gin.Context) {
	bookingID := c.Param("id")
	userID := c.GetString("user_id")
	userRole := c.GetString("role")

	msgs, err := h.bookingService.ListMessages(c.Request.Context(), bookingID, userID, userRole)
	if err != nil {
		utils.Error(c, http.StatusForbidden, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, msgs)
}

// --- OTP verification ---

type bookingOTPVerifyBody struct {
	OTP string `json:"otp" binding:"required"`
}

// GetOTP powers the customer's own Booking Tracking screen — shows the
// on-screen code they read out to the technician, exactly like a
// ride-hailing app's start-ride PIN. Only the booking's own customer (or an
// admin) may see it.
func (h *BookingHandler) GetOTP(c *gin.Context) {
	bookingID := c.Param("id")
	userID := c.GetString("user_id")
	userRole := c.GetString("role")

	b, err := h.bookingService.Get(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if b == nil {
		utils.Error(c, http.StatusNotFound, "booking not found")
		return
	}
	if userRole != "admin" && b.CustomerID != userID {
		utils.Error(c, http.StatusForbidden, "not authorized to view this booking's OTP")
		return
	}

	otp, err := h.bookingService.GetOTP(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"otp": otp})
}

// VerifyOTP is called by the technician's app after the customer reads out
// the code shown on their screen. Success moves the booking into
// "inspecting" so the technician can start diagnosing on record.
func (h *BookingHandler) VerifyOTP(c *gin.Context) {
	bookingID := c.Param("id")
	var body bookingOTPVerifyBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	ok, err := h.bookingService.VerifyOTP(c.Request.Context(), bookingID, body.OTP)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if !ok {
		utils.Error(c, http.StatusBadRequest, "incorrect OTP")
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "OTP verified, service started"})
}

// --- Live technician location ---

// GetTechnicianLocation powers the customer's live tracking map. Only the
// booking's own customer (or an admin) may see it.
func (h *BookingHandler) GetTechnicianLocation(c *gin.Context) {
	bookingID := c.Param("id")
	userID := c.GetString("user_id")
	userRole := c.GetString("role")

	b, err := h.bookingService.Get(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if b == nil {
		utils.Error(c, http.StatusNotFound, "booking not found")
		return
	}
	if userRole != "admin" && b.CustomerID != userID {
		utils.Error(c, http.StatusForbidden, "not authorized to view this booking's location")
		return
	}

	lat, lng, updatedAt, err := h.bookingService.TechnicianLocation(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{
		"latitude":   lat,
		"longitude":  lng,
		"updated_at": updatedAt,
	})
}

// --- Service estimate ---

type estimateItemBody struct {
	Description string  `json:"description" binding:"required"`
	Amount      float64 `json:"amount" binding:"required"`
}

type submitEstimateBody struct {
	Items []estimateItemBody `json:"items" binding:"required"`
	Note  string             `json:"note"`
}

// SubmitEstimate is called by the technician (directly, or again after the
// customer asked to "discuss") to raise or revise the itemised quote.
func (h *BookingHandler) SubmitEstimate(c *gin.Context) {
	bookingID := c.Param("id")
	var body submitEstimateBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	items := make([]models.BookingEstimateItem, 0, len(body.Items))
	for _, it := range body.Items {
		items = append(items, models.BookingEstimateItem{Description: it.Description, Amount: it.Amount})
	}
	est, err := h.bookingService.SubmitEstimate(c.Request.Context(), bookingID, items, body.Note)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, est)
}

// GetEstimate lets either side (customer waiting for a decision, or
// technician checking status) view the current estimate.
func (h *BookingHandler) GetEstimate(c *gin.Context) {
	bookingID := c.Param("id")
	est, err := h.bookingService.GetEstimate(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if est == nil {
		utils.Error(c, http.StatusNotFound, "no estimate found for this booking")
		return
	}
	utils.Success(c, http.StatusOK, est)
}

type estimateDecisionBody struct {
	Decision string `json:"decision" binding:"required"` // "approve" | "decline"
}

// RespondToEstimate is the customer's Approve / Decline button. "Discuss" is
// intentionally not a decision here — it's just opening chat with the
// technician, who then resubmits a revised estimate via SubmitEstimate.
func (h *BookingHandler) RespondToEstimate(c *gin.Context) {
	bookingID := c.Param("id")
	userID := c.GetString("user_id")

	b, err := h.bookingService.Get(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if b == nil {
		utils.Error(c, http.StatusNotFound, "booking not found")
		return
	}
	if b.CustomerID != userID {
		utils.Error(c, http.StatusForbidden, "not authorized to respond to this booking's estimate")
		return
	}

	var body estimateDecisionBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.bookingService.RespondToEstimate(c.Request.Context(), bookingID, body.Decision); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "estimate " + body.Decision + "d"})
}

// --- Before/after service photos ---

type addPhotoBody struct {
	PhotoURL  string `json:"photo_url" binding:"required"`
	PhotoType string `json:"photo_type" binding:"required"` // "before" | "after"
}

func (h *BookingHandler) AddServicePhoto(c *gin.Context) {
	bookingID := c.Param("id")
	var body addPhotoBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	photo, err := h.bookingService.AddServicePhoto(c.Request.Context(), bookingID, body.PhotoURL, body.PhotoType)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, photo)
}

func (h *BookingHandler) ListServicePhotos(c *gin.Context) {
	bookingID := c.Param("id")
	photos, err := h.bookingService.ListServicePhotos(c.Request.Context(), bookingID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, photos)
}