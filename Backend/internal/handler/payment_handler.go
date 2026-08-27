package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type PaymentHandler struct {
	upi *service.UpiService
	fcm *service.FirebaseService
}

func NewPaymentHandler(upi *service.UpiService, fcm *service.FirebaseService) *PaymentHandler {
	return &PaymentHandler{upi: upi, fcm: fcm}
}

type createOrderBody struct {
	BookingID string  `json:"booking_id" binding:"required"`
	Amount    float64 `json:"amount" binding:"required"`
}

// CreateOrder returns a upi://pay deep link the app launches with url_launcher —
// GPay, PhonePe, Paytm etc. all register as handlers for it, so Android shows
// whichever the customer has installed (or opens GPay directly if it's the only one).
func (h *PaymentHandler) CreateOrder(c *gin.Context) {
	userID := c.GetString("user_id")
	var body createOrderBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	order, err := h.upi.CreateOrder(c.Request.Context(), body.BookingID, userID, body.Amount)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, order)
}

type confirmPaymentBody struct {
	TransactionRef string `json:"transaction_ref" binding:"required"`
	// UpiTxnID/UpiStatus/UpiResponseCode/UpiApprovalRef come straight from the UPI
	// app's OWN response to the launching app (startActivityForResult) — never a
	// value the client invents. UpiStatus must be "SUCCESS" for this to ever mark
	// the payment (and its booking) paid — see UpiService.ConfirmPayment.
	UpiTxnID        string `json:"upi_txn_id"`
	UpiStatus       string `json:"upi_status" binding:"required"`
	UpiResponseCode string `json:"upi_response_code"`
	UpiApprovalRef  string `json:"upi_approval_ref"`
	Method          string `json:"method"`
}

// Confirm marks the payment paid ONLY once the UPI app's own response (reported by
// the app after the intent returns) indicates a real SUCCESS — see
// UpiService.ConfirmPayment for why this is the most a raw UPI intent (no
// PSP/gateway callback) can honestly verify. Generates an invoice number and sends
// a "Payment success" notification.
func (h *PaymentHandler) Confirm(c *gin.Context) {
	var body confirmPaymentBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	payment, err := h.upi.ConfirmPayment(
		c.Request.Context(), body.TransactionRef, body.UpiTxnID, body.Method,
		body.UpiStatus, body.UpiResponseCode, body.UpiApprovalRef,
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
// back, customer credited the full amount to their in-app wallet.
func (h *PaymentHandler) Refund(c *gin.Context) {
	payment, err := h.upi.Refund(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	if h.fcm != nil {
		_ = h.fcm.SendToUser(c.Request.Context(), payment.UserID, "Refund processed",
			"Your payment has been refunded to your HomeFix wallet.",
			map[string]string{"booking_id": payment.BookingID, "payment_id": payment.ID, "type": "refund"})
	}

	utils.Success(c, http.StatusOK, payment)
}

// Fail lets the app tell us a UPI payment was cancelled/failed (e.g. the user backed
// out of GPay) so the payment record — and any retry UI — reflects that accurately.
type failPaymentBody struct {
	TransactionRef string `json:"transaction_ref" binding:"required"`
}

func (h *PaymentHandler) Fail(c *gin.Context) {
	var body failPaymentBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.upi.MarkFailed(c.Request.Context(), body.TransactionRef); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "payment marked failed"})
}

// History powers the customer's Payment History screen.
func (h *PaymentHandler) History(c *gin.Context) {
	userID := c.GetString("user_id")
	list, err := h.upi.ListByUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}