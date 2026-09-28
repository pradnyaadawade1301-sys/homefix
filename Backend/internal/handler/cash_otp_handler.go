package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/utils"
)

// GetCashOTP — GET /payments/:id/cash-otp. The customer's app shows this code
// on the "Pay by cash" screen; they read it to the technician after handing
// over the cash. Only the payment's own customer can fetch it.
func (h *PaymentHandler) GetCashOTP(c *gin.Context) {
	otp, err := h.razorpay.GetCashOTP(c.Request.Context(), c.Param("id"), c.GetString("user_id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"otp": otp})
}

// RefreshCashOTP — POST /payments/:id/cash-otp/refresh. Customer-only "New OTP".
func (h *PaymentHandler) RefreshCashOTP(c *gin.Context) {
	otp, err := h.razorpay.RefreshCashOTP(c.Request.Context(), c.Param("id"), c.GetString("user_id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"otp": otp})
}
