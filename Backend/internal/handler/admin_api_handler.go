package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

// AdminAPIHandler powers the new React Admin Panel — a JSON API, separate
// from the older cookie-session /admin panel (internal/admin, still used for
// the hidden ops tools: CMS, disputes, inventory). This handler only covers
// the read surfaces the React Admin Panel needs: Dashboard, Orders,
// Customers, Bookings, Technicians. All routes require role "admin" (see
// router.go).
type AdminAPIHandler struct {
	userRepo       *repository.UserRepository
	bookingRepo    *repository.BookingRepository
	technicianRepo *repository.TechnicianRepository
	paymentRepo    *repository.PaymentRepository
}

func NewAdminAPIHandler(
	userRepo *repository.UserRepository,
	bookingRepo *repository.BookingRepository,
	technicianRepo *repository.TechnicianRepository,
	paymentRepo *repository.PaymentRepository,
) *AdminAPIHandler {
	return &AdminAPIHandler{
		userRepo:       userRepo,
		bookingRepo:    bookingRepo,
		technicianRepo: technicianRepo,
		paymentRepo:    paymentRepo,
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

	utils.Success(c, http.StatusOK, gin.H{
		"total_customers":    len(customers),
		"total_technicians":  len(technicians),
		"total_bookings":     len(bookings),
		"active_bookings":    activeBookings,
		"completed_bookings": completedBookings,
		"total_revenue":      totalRevenue,
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
