package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/repository"
	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

// FinanceHandler powers the new React Finance Panel — a JSON API, separate
// from the older cookie-session /admin panel (internal/admin). Reuses the
// existing PaymentRepository/WalletRepository/UpiService rather than
// duplicating any money logic; this is a read+refund surface only.
type FinanceHandler struct {
	paymentRepo *repository.PaymentRepository
	walletRepo  *repository.WalletRepository
	upi         *service.UpiService
}

func NewFinanceHandler(paymentRepo *repository.PaymentRepository, walletRepo *repository.WalletRepository, upi *service.UpiService) *FinanceHandler {
	return &FinanceHandler{paymentRepo: paymentRepo, walletRepo: walletRepo, upi: upi}
}

// Collections — GET /finance/collections?status=paid
// All payments the platform has collected from customers. Defaults to "paid"
// so the default view is "money actually received", not every attempted order.
func (h *FinanceHandler) Collections(c *gin.Context) {
	status := c.DefaultQuery("status", "paid")
	payments, err := h.paymentRepo.ListAll(c.Request.Context(), status)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}

	var totalCollected, totalCommission, totalTechnicianEarning float64
	for _, p := range payments {
		totalCollected += p.Amount
		if p.PlatformCommission != nil {
			totalCommission += *p.PlatformCommission
		}
		if p.TechnicianEarning != nil {
			totalTechnicianEarning += *p.TechnicianEarning
		}
	}

	utils.Success(c, http.StatusOK, gin.H{
		"payments": payments,
		"summary": gin.H{
			"total_collected":           totalCollected,
			"total_platform_commission": totalCommission,
			"total_technician_earning":  totalTechnicianEarning,
			"count":                     len(payments),
		},
	})
}

// GSTReport — GET /finance/gst-report
// Aggregates GST collected across all paid payments. Reuses the base_amount/
// gst_amount/gst_percent columns UpiService already populates on CreateOrder
// (see UpiService.CreateOrder) — no separate ledger needed.
func (h *FinanceHandler) GSTReport(c *gin.Context) {
	payments, err := h.paymentRepo.ListAll(c.Request.Context(), "paid")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}

	var totalBase, totalGST float64
	rows := make([]gin.H, 0, len(payments))
	for _, p := range payments {
		base := 0.0
		gst := 0.0
		if p.BaseAmount != nil {
			base = *p.BaseAmount
		}
		if p.GstAmount != nil {
			gst = *p.GstAmount
		}
		totalBase += base
		totalGST += gst
		rows = append(rows, gin.H{
			"payment_id":     p.ID,
			"booking_id":     p.BookingID,
			"invoice_number": p.InvoiceNumber,
			"base_amount":    base,
			"gst_amount":     gst,
			"gst_percent":    p.GstPercent,
			"total_amount":   p.Amount,
			"created_at":     p.CreatedAt,
		})
	}

	utils.Success(c, http.StatusOK, gin.H{
		"rows": rows,
		"summary": gin.H{
			"total_base_amount":   totalBase,
			"total_gst_collected": totalGST,
			"count":               len(rows),
		},
	})
}

// Refunds — GET /finance/refunds
// Every refunded payment, for reconciliation.
func (h *FinanceHandler) Refunds(c *gin.Context) {
	payments, err := h.paymentRepo.ListAll(c.Request.Context(), "refunded")
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, payments)
}

// RefundPayment — POST /finance/payments/:id/refund
// Finance-panel counterpart of PaymentHandler.Refund (which is admin-only).
// Shares the exact same UpiService.Refund logic — wallet clawback + customer
// credit — just reachable from the finance role too.
func (h *FinanceHandler) RefundPayment(c *gin.Context) {
	payment, err := h.upi.Refund(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, payment)
}

// Payouts — GET /finance/payouts
// Technician wallet balances + their credit/debit ledger. Payout means "what
// a technician has earned and can be settled to them" — this reads directly
// from the wallet ledger (see WalletRepository) rather than inventing a
// separate payouts table, since wallet credits/debits already ARE the payout
// ledger (booking_earning credits, booking_refund_clawback debits, etc.).
func (h *FinanceHandler) Payouts(c *gin.Context) {
	userID := c.Query("user_id")
	if userID == "" {
		utils.Error(c, http.StatusBadRequest, "user_id query param is required")
		return
	}
	wallet, err := h.walletRepo.GetOrCreate(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	history, err := h.walletRepo.History(c.Request.Context(), wallet.ID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{
		"wallet":       wallet,
		"transactions": history,
	})
}