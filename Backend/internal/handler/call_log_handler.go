package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

// CallLogHandler serves the real call-history list (who called, when,
// missed/received) — used by both the customer app's Consult > Call tab
// and the technician app's History > Call tab, since it's just scoped to
// whoever is authenticated.
type CallLogHandler struct {
	callLogRepo *repository.CallLogRepository
}

func NewCallLogHandler(callLogRepo *repository.CallLogRepository) *CallLogHandler {
	return &CallLogHandler{callLogRepo: callLogRepo}
}

// History - GET /calls/history
func (h *CallLogHandler) History(c *gin.Context) {
	userID := c.GetString("user_id")

	entries, err := h.callLogRepo.ListForUser(c.Request.Context(), userID, 200)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.Success(c, http.StatusOK, gin.H{"calls": entries})
}