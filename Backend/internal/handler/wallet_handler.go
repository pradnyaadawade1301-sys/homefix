package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type WalletHandler struct {
	walletService *service.WalletService
}

func NewWalletHandler(walletService *service.WalletService) *WalletHandler {
	return &WalletHandler{walletService: walletService}
}

func (h *WalletHandler) Balance(c *gin.Context) {
	userID := c.GetString("user_id")
	w, err := h.walletService.GetBalance(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, w)
}

func (h *WalletHandler) History(c *gin.Context) {
	userID := c.GetString("user_id")
	hist, err := h.walletService.History(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, hist)
}

type walletAdjustBody struct {
	Amount float64 `json:"amount" binding:"required"`
	Reason string  `json:"reason"`
}

func (h *WalletHandler) Credit(c *gin.Context) {
	userID := c.GetString("user_id")
	var body walletAdjustBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	w, err := h.walletService.Credit(c.Request.Context(), userID, body.Amount, body.Reason, nil)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, w)
}

func (h *WalletHandler) Debit(c *gin.Context) {
	userID := c.GetString("user_id")
	var body walletAdjustBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	w, err := h.walletService.Debit(c.Request.Context(), userID, body.Amount, body.Reason, nil)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, w)
}