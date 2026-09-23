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
	walletService  *service.WalletService
}

func NewAdminAPIHandler(
	userRepo *repository.UserRepository,
	bookingRepo *repository.BookingRepository,
	technicianRepo *repository.TechnicianRepository,
	paymentRepo *repository.PaymentRepository,
	disputeService *service.DisputeService,
	walletService *service.WalletService,
) *AdminAPIHandler {
	return &AdminAPIHandler{
		userRepo:       userRepo,
		bookingRepo:    bookingRepo,
		technicianRepo: technicianRepo,
		paymentRepo:    paymentRepo,
		disputeService: disputeService,
		walletService:  walletService,
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

// BookingPhotos — GET /admin/bookings/:id/photos — the technician's
// before/after proof-of-work photos for a booking (see JobPhotosSheet on the
// technician app, which uploads these; "after" is required before a booking
// can be marked completed — see BookingService.Complete).
func (h *AdminAPIHandler) BookingPhotos(c *gin.Context) {
	photos, err := h.bookingRepo.ListServicePhotos(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, photos)
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

// DisputeDetail — GET /admin/disputes/:id/evidence
// The list view (Disputes above) can't reasonably embed photo evidence per
// row, so the React panel fetches it here only when an admin opens/expands
// a specific dispute.
func (h *AdminAPIHandler) DisputeDetail(c *gin.Context) {
	d, evidence, err := h.disputeService.GetForAdmin(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if d == nil {
		utils.Error(c, http.StatusNotFound, "dispute not found")
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"dispute": d, "evidence": evidence})
}

// TechnicianWallet — GET /admin/technicians/:id/wallet
// Lets an admin check a technician's balance (and how it got there) before
// deciding whether/how much to top up — e.g. when support gets a "COD keeps
// failing" ticket, this is usually the first thing to check (see
// RazorpayService.CreateCodOrder's low-balance guard).
func (h *AdminAPIHandler) TechnicianWallet(c *gin.Context) {
	technicianUserID := c.Param("id")
	wallet, err := h.walletService.GetBalance(c.Request.Context(), technicianUserID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	history, err := h.walletService.History(c.Request.Context(), technicianUserID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"wallet": wallet, "transactions": history})
}

// CreditTechnicianWallet — POST /admin/technicians/:id/wallet/credit
// The actual top-up action: manually credits a specific technician's wallet
// (by path id, not the caller's own id — unlike the older self-serve
// POST /wallet/credit, which can only ever credit the admin's own wallet and
// isn't useful for this). Typical use: a new technician's wallet is ₹0 (no
// online-paid job completed yet — see WalletService.Credit's only other
// caller, BookingService.Complete's earning credit) so every Cash-on-Delivery
// job silently fails the platform-commission check; support tops them up
// here to unblock COD until they've completed a paid job of their own.
type creditTechnicianWalletBody struct {
	Amount float64 `json:"amount" binding:"required,gt=0"`
	Reason string  `json:"reason"`
}

func (h *AdminAPIHandler) CreditTechnicianWallet(c *gin.Context) {
	technicianUserID := c.Param("id")
	var body creditTechnicianWalletBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	reason := body.Reason
	if reason == "" {
		reason = "admin_topup"
	}
	adminID := c.GetString("user_id")
	wallet, err := h.walletService.Credit(c.Request.Context(), technicianUserID, body.Amount, reason, &adminID)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, wallet)
}