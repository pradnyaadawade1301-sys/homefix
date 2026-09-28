package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

// SupportHandler is the customer/technician-facing half of the general
// "Contact Support" live chat (Profile screen), separate from
// DisputeHandler which is always scoped to a specific booking/consultation.
type SupportHandler struct {
	svc *service.SupportService
}

func NewSupportHandler(svc *service.SupportService) *SupportHandler {
	return &SupportHandler{svc: svc}
}

// Message is intentionally not "required" — a message can be just a
// photo/video with no caption. SupportService.SendMessage rejects a truly
// empty (no text, no attachment) message.
type sendSupportMessageBody struct {
	Message        string `json:"message"`
	AttachmentURL  string `json:"attachment_url"`
	AttachmentType string `json:"attachment_type"` // "image" | "video"
}

// SendMessage — POST /support/messages. To attach a photo/video: upload it
// first via POST /uploads (multipart, returns {"url": ...}), then pass that
// URL here as attachment_url along with attachment_type "image" or "video".
func (h *SupportHandler) SendMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	var body sendSupportMessageBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	m, err := h.svc.SendMessage(c.Request.Context(), userID, body.Message, body.AttachmentURL, body.AttachmentType)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, m)
}

// ListMessages — GET /support/messages. Frontend polls this every few
// seconds while the chat screen is open.
func (h *SupportHandler) ListMessages(c *gin.Context) {
	userID := c.GetString("user_id")
	list, err := h.svc.ListMessages(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}
