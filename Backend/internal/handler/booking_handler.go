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
	list, err := h.bookingService.ListForTechnicianDetailed(c.Request.Context(), technicianID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
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

type completeBody struct {
	FinalPrice float64 `json:"final_price" binding:"required"`
}

func (h *BookingHandler) Complete(c *gin.Context) {
	bookingID := c.Param("id")
	var body completeBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.bookingService.Complete(c.Request.Context(), bookingID, body.FinalPrice); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "booking completed"})
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