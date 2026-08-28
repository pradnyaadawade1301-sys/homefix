package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type PaymentHandler struct {
	razorpay *service.RazorpayService
	fcm      *service.FirebaseService
}

func NewPaymentHandler(razorpay *service.RazorpayService, fcm *service.FirebaseService) *PaymentHandler {
	return &PaymentHandler{razorpay: razorpay, fcm: fcm}
}

type createOrderBody struct {
	BookingID string  `json:"booking_id" binding:"required"`
	Amount    float64 `json:"amount" binding:"required"`
}

// CreateOrder creates a real Razorpay order and returns what the app needs to
// open Razorpay Checkout (order_id + the public key_id + amount).
func (h *PaymentHandler) CreateOrder(c *gin.Context) {
	userID := c.GetString("user_id")
	var body createOrderBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	order, err := h.razorpay.CreateOrder(c.Request.Context(), body.BookingID, userID, body.Amount)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, order)
}

type confirmPaymentBody struct {
	// RazorpayOrderID/RazorpayPaymentID/RazorpaySignature come straight from
	// Razorpay Checkout's OWN success callback on the app — never values the
	// client invents. The backend independently re-verifies the signature
	// server-side (see RazorpayService.VerifyAndCapture) before ever marking
	// this payment (and its booking) paid.
	RazorpayOrderID   string `json:"razorpay_order_id" binding:"required"`
	RazorpayPaymentID string `json:"razorpay_payment_id" binding:"required"`
	RazorpaySignature string `json:"razorpay_signature" binding:"required"`
	Method            string `json:"method"`
}

// Confirm marks the payment paid ONLY once the Razorpay signature has been
// independently re-verified server-side — see RazorpayService.VerifyAndCapture.
// Generates an invoice number and sends a "Payment success" notification.
func (h *PaymentHandler) Confirm(c *gin.Context) {
	var body confirmPaymentBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	payment, err := h.razorpay.VerifyAndCapture(
		c.Request.Context(), body.RazorpayOrderID, body.RazorpayPaymentID, body.RazorpaySignature, body.Method,
	)
	if err != nil {
		status := http.StatusBadRequest
		if err == service.ErrPaymentNotVerified {
			status = http.StatusUnprocessableEntity
		}
		utils.Error(c, status, err.Error())
		return
	}

	if h.fcm != nil {
		_ = h.fcm.SendToUser(c.Request.Context(), payment.UserID, "Payment successful",
			"Your payment for booking has been received. Thank you!",
			map[string]string{"booking_id": payment.BookingID, "payment_id": payment.ID, "type": "payment_success"})
	}

	utils.Success(c, http.StatusOK, payment)
}

// Refund — POST /payments/:id/refund (admin only, see router.go). Reverses a
// verified payment: booking.payment_status -> refunded, technician earning clawed
// back, customer credited the full amount to their in-app wallet (and, if the
// payment actually went through Razorpay, a real gateway refund is also issued).
func (h *PaymentHandler) Refund(c *gin.Context) {
	payment, err := h.razorpay.Refund(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	if h.fcm != nil {
		_ = h.fcm.SendToUser(c.Request.Context(), payment.UserID, "Refund processed",
			"Your payment has been refunded.",
			map[string]string{"booking_id": payment.BookingID, "payment_id": payment.ID, "type": "refund"})
	}

	utils.Success(c, http.StatusOK, payment)
}

// Fail lets the app tell us a Razorpay payment was cancelled/dismissed/failed
// (e.g. the user backed out of the payment sheet) so the payment record — and any
// retry UI — reflects that accurately.
type failPaymentBody struct {
	RazorpayOrderID string `json:"razorpay_order_id" binding:"required"`
}

func (h *PaymentHandler) Fail(c *gin.Context) {
	var body failPaymentBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.razorpay.MarkFailed(c.Request.Context(), body.RazorpayOrderID); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "payment marked failed"})
}

// History powers the customer's Payment History screen.
func (h *PaymentHandler) History(c *gin.Context) {
	userID := c.GetString("user_id")
	list, err := h.razorpay.ListByUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}

// GetInvoice — GET /payments/:id/invoice. Returns the full GST-compliant
// invoice (base amount, CGST, SGST, total, service ID) once payment is
// complete — see RazorpayService.GetInvoice.
func (h *PaymentHandler) GetInvoice(c *gin.Context) {
	userID := c.GetString("user_id")
	invoice, err := h.razorpay.GetInvoice(c.Request.Context(), c.Param("id"), userID)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, invoice)
}