package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

// DisputeHandler is the customer/technician-facing half of the dispute module
// (raise + track + upload evidence). Resolution (admin decision, refund) only
// ever happens from the hidden /admin panel — see internal/admin/disputes.go.
type DisputeHandler struct {
	svc *service.DisputeService
}

func NewDisputeHandler(svc *service.DisputeService) *DisputeHandler {
	return &DisputeHandler{svc: svc}
}

type raiseDisputeBody struct {
	BookingID      string `json:"booking_id"`
	ConsultationID string `json:"consultation_id"`
	Reason         string `json:"reason" binding:"required"`
}

func (h *DisputeHandler) Raise(c *gin.Context) {
	userID := c.GetString("user_id")
	var body raiseDisputeBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	var bookingID, consultationID *string
	if body.BookingID != "" {
		bookingID = &body.BookingID
	}
	if body.ConsultationID != "" {
		consultationID = &body.ConsultationID
	}

	d, err := h.svc.Raise(c.Request.Context(), bookingID, consultationID, userID, body.Reason)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, d)
}

type addEvidenceBody struct {
	FileURL string `json:"file_url" binding:"required"`
	Note    string `json:"note"`
}

func (h *DisputeHandler) AddEvidence(c *gin.Context) {
	userID := c.GetString("user_id")
	var body addEvidenceBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	e, err := h.svc.AddEvidence(c.Request.Context(), c.Param("id"), userID, body.FileURL, body.Note)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, e)
}

func (h *DisputeHandler) Get(c *gin.Context) {
	userID := c.GetString("user_id")
	d, evidence, err := h.svc.GetForUser(c.Request.Context(), c.Param("id"), userID)
	if err != nil {
		utils.Error(c, http.StatusForbidden, err.Error())
		return
	}
	if d == nil {
		utils.Error(c, http.StatusNotFound, "dispute not found")
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"dispute": d, "evidence": evidence})
}

func (h *DisputeHandler) ListMine(c *gin.Context) {
	userID := c.GetString("user_id")
	list, err := h.svc.ListForUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}

// Message is intentionally not "required" here — a message can be just a
// photo/video with no caption. DisputeService.SendMessage is what actually
// rejects a truly empty (no text, no attachment) message.
type sendDisputeMessageBody struct {
	Message        string `json:"message"`
	AttachmentURL  string `json:"attachment_url"`
	AttachmentType string `json:"attachment_type"` // "image" | "video"
}

// SendMessage — POST /disputes/:id/messages (customer/technician side).
// To attach a photo/video: upload it first via POST /uploads (multipart,
// returns {"url": ...}), then pass that URL here as attachment_url along
// with attachment_type "image" or "video".
func (h *DisputeHandler) SendMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	var body sendDisputeMessageBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	m, err := h.svc.SendMessage(c.Request.Context(), c.Param("id"), userID, body.Message, body.AttachmentURL, body.AttachmentType)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, m)
}

// ListMessages — GET /disputes/:id/messages (customer/technician side).
// Frontend polls this every few seconds while the chat screen is open.
func (h *DisputeHandler) ListMessages(c *gin.Context) {
	userID := c.GetString("user_id")
	list, err := h.svc.ListMessages(c.Request.Context(), c.Param("id"), userID)
	if err != nil {
		utils.Error(c, http.StatusForbidden, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}
