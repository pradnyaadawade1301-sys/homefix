package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type DueHandler struct{ dues *service.DueService }

func NewDueHandler(d *service.DueService) *DueHandler { return &DueHandler{dues: d} }

// Summary — GET /technician/dues
func (h *DueHandler) Summary(c *gin.Context) {
	s, err := h.dues.Summary(c.Request.Context(), c.GetString("user_id"))
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, s)
}

// Pay — POST /technician/dues/pay : creates the Razorpay order for all pending dues.
func (h *DueHandler) Pay(c *gin.Context) {
	o, err := h.dues.CreateSettlementOrder(c.Request.Context(), c.GetString("user_id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, o)
}

type verifyDueBody struct {
	OrderID   string `json:"razorpay_order_id" binding:"required"`
	PaymentID string `json:"razorpay_payment_id" binding:"required"`
	Signature string `json:"razorpay_signature" binding:"required"`
}

// Verify — POST /technician/dues/verify : clears dues after Razorpay Checkout succeeds.
func (h *DueHandler) Verify(c *gin.Context) {
	var b verifyDueBody
	if err := c.ShouldBindJSON(&b); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	s, err := h.dues.VerifySettlement(c.Request.Context(), c.GetString("user_id"), b.OrderID, b.PaymentID, b.Signature)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, s)
}
