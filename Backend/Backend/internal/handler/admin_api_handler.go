package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/repository"
	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

// AdminAPIHandler powers the new React Admin Panel — a JSON API, separate
// from the older cookie-session /admin panel (internal/admin, still used for
// the hidden ops tools: CMS and inventory). This handler covers the read
// surfaces the React Admin Panel needs: Dashboard, Orders, Customers,
// Bookings, Technicians, and Disputes (view + resolve). All routes require
// role "admin" (see router.go).
type AdminAPIHandler struct {
	userRepo       *repository.UserRepository
	bookingRepo    *repository.BookingRepository
	technicianRepo *repository.TechnicianRepository
	paymentRepo    *repository.PaymentRepository
	disputeService *service.DisputeService
}

func NewAdminAPIHandler(
	userRepo *repository.UserRepository,
	bookingRepo *repository.BookingRepository,
	technicianRepo *repository.TechnicianRepository,
	paymentRepo *repository.PaymentRepository,
	disputeService *service.DisputeService,
) *AdminAPIHandler {
	return &AdminAPIHandler{
		userRepo:       userRepo,
		bookingRepo:    bookingRepo,
		technicianRepo: technicianRepo,
		paymentRepo:    paymentRepo,
		disputeService: disputeService,
	}
}

// Dashboard — GET /admin/dashboard
// Headline counts for the panel's landing page. Kept to cheap COUNT-style
// reads (via existing list methods) rather than a new aggregate query, since
// admin dashboard traffic is low and correctness > a few extra ms.
func (h *AdminAPIHandler) Dashboard(c *gin.Context) {
	ctx := c.Request.Context()

	customers, err := h.userRepo.ListAll(ctx, "customer")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	technicians, err := h.userRepo.ListAll(ctx, "technician")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	bookings, err := h.bookingRepo.ListAllDetailed(ctx, "")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	payments, err := h.paymentRepo.ListAll(ctx, "paid")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}

	var totalRevenue float64
	for _, p := range payments {
		totalRevenue += p.Amount
	}

	var activeBookings, completedBookings int
	for _, b := range bookings {
		switch b.Status {
		case "accepted", "in_progress", "requested":
			activeBookings++
		case "completed":
			completedBookings++
		}
	}

	openDisputes, err := h.disputeService.CountOpen(ctx)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.Success(c, http.StatusOK, gin.H{
		"total_customers":    len(customers),
		"total_technicians":  len(technicians),
		"total_bookings":     len(bookings),
		"active_bookings":    activeBookings,
		"completed_bookings": completedBookings,
		"total_revenue":      totalRevenue,
		"open_disputes":      openDisputes,
	})
}

// Orders — GET /admin/orders?status=
// Alias over Bookings for panels that think of them as "orders". Status is
// optional; ListAllDetailed treats "" as no filter.
func (h *AdminAPIHandler) Orders(c *gin.Context) {
	status := c.Query("status")
	bookings, err := h.bookingRepo.ListAllDetailed(c.Request.Context(), status)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, bookings)
}

// Bookings — GET /admin/bookings?status=
func (h *AdminAPIHandler) Bookings(c *gin.Context) {
	status := c.Query("status")
	bookings, err := h.bookingRepo.ListAllDetailed(c.Request.Context(), status)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, bookings)
}

// Customers — GET /admin/customers
func (h *AdminAPIHandler) Customers(c *gin.Context) {
	customers, err := h.userRepo.ListAll(c.Request.Context(), "customer")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, customers)
}

// Technicians — GET /admin/technicians?status=approved|pending|rejected
// Defaults to "pending" (the most common admin action — reviewing new
// applications) when no status is given, since ListByApprovalStatus expects
// an exact match rather than "all".
func (h *AdminAPIHandler) Technicians(c *gin.Context) {
	status := c.DefaultQuery("status", "pending")
	technicians, err := h.technicianRepo.ListByApprovalStatus(c.Request.Context(), status)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, technicians)
}

// Disputes — GET /admin/disputes?status=
// Same read as the hidden /admin panel's dispute list (DisputeService.ListAll),
// just returned as JSON for the React panel instead of rendered HTML.
func (h *AdminAPIHandler) Disputes(c *gin.Context) {
	status := c.Query("status")
	disputes, err := h.disputeService.ListAll(c.Request.Context(), status)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, disputes)
}

// ResolveDispute — PATCH /admin/disputes/:id/resolve
// Mirrors the hidden /admin panel's resolve action: status must be one of
// resolved_refund | resolved_partial | resolved_rejected. refund_amount is
// only required/used for the two refund outcomes.
type resolveDisputeBody struct {
	Status       string   `json:"status" binding:"required"`
	AdminNotes   string   `json:"admin_notes"`
	RefundAmount *float64 `json:"refund_amount"`
}

func (h *AdminAPIHandler) ResolveDispute(c *gin.Context) {
	var body resolveDisputeBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	adminID := c.GetString("user_id")
	d, err := h.disputeService.Resolve(c.Request.Context(), c.Param("id"), body.Status, body.AdminNotes, adminID, body.RefundAmount)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, d)
}

// ReviewDispute — PATCH /admin/disputes/:id/review
// Marks a dispute "under_review" — the same first step available in the
// hidden /admin panel, before an admin picks a final resolution.
func (h *AdminAPIHandler) ReviewDispute(c *gin.Context) {
	id := c.Param("id")
	if err := h.disputeService.MarkUnderReview(c.Request.Context(), id); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"id": id, "status": "under_review"})
}