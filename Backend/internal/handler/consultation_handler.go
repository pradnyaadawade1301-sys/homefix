package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type ConsultationHandler struct {
	consultSvc *service.ConsultationService
	stunURLs   []string
	turnURL    string
	turnSecret string
	turnTTL    time.Duration
}

func NewConsultationHandler(consultSvc *service.ConsultationService, stunURLs []string, turnURL, turnSecret string, turnTTLSeconds int) *ConsultationHandler {
	return &ConsultationHandler{
		consultSvc: consultSvc,
		stunURLs:   stunURLs,
		turnURL:    turnURL,
		turnSecret: turnSecret,
		turnTTL:    time.Duration(turnTTLSeconds) * time.Second,
	}
}

// Request - POST /consultations/request. Customer starts "Live Consultation".
// scheduled_at is optional: omitted/nil = instant "Consult Now" (unchanged
// behavior — technician is rung immediately). Present = "Schedule for later" —
// the technician is asked to confirm holding that slot instead of being rung
// right away; the backend automatically rings both sides when the slot arrives
// (see ConsultationService.PromoteDueScheduled, polled from main.go).
func (h *ConsultationHandler) Request(c *gin.Context) {
	userID := c.GetString("user_id")

	var body struct {
		CategoryID            string     `json:"category_id" binding:"required"`
		PreferredTechnicianID string     `json:"preferred_technician_id"`
		Latitude              *float64   `json:"latitude"`
		Longitude             *float64   `json:"longitude"`
		ScheduledAt           *time.Time `json:"scheduled_at"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	result, err := h.consultSvc.Request(c.Request.Context(), userID, body.CategoryID, body.PreferredTechnicianID, body.Latitude, body.Longitude, body.ScheduledAt)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, result)
}

// Get - GET /consultations/:id. Customer polls this while the screen shows
// "Searching...", "Ringing...", etc.
func (h *ConsultationHandler) Get(c *gin.Context) {
	result, err := h.consultSvc.Get(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if result == nil {
		utils.Error(c, http.StatusNotFound, "consultation not found")
		return
	}
	utils.Success(c, http.StatusOK, result)
}

// Accept - POST /consultations/:id/accept. Technician accepts the incoming request
// (instant flow, or a scheduled one whose slot has arrived and is now 'ringing').
func (h *ConsultationHandler) Accept(c *gin.Context) {
	userID := c.GetString("user_id")
	result, err := h.consultSvc.AcceptByUser(c.Request.Context(), c.Param("id"), userID)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, result)
}

// Reject - POST /consultations/:id/reject. Technician declines the incoming request.
// reason is optional free text explaining why (shown to the customer).
func (h *ConsultationHandler) Reject(c *gin.Context) {
	userID := c.GetString("user_id")

	var body struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&body) // optional body — a plain empty POST is still valid

	if err := h.consultSvc.RejectByUser(c.Request.Context(), c.Param("id"), userID, body.Reason); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"status": "rejected"})
}

// ConfirmScheduled - POST /consultations/:id/confirm-scheduled. Technician confirms
// they can hold a "Schedule for later" slot ahead of time — distinct from Accept,
// which is for a live incoming call. Nobody is connected yet; this just locks in
// the appointment.
func (h *ConsultationHandler) ConfirmScheduled(c *gin.Context) {
	userID := c.GetString("user_id")
	result, err := h.consultSvc.ConfirmScheduledByUser(c.Request.Context(), c.Param("id"), userID)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, result)
}

// DeclineScheduled - POST /consultations/:id/decline-scheduled. Technician can't
// make a proposed slot; customer is notified to pick another time. reason is
// optional free text explaining why — shown to the customer (and stored on the
// consultation) instead of a bare "declined" with no context.
func (h *ConsultationHandler) DeclineScheduled(c *gin.Context) {
	userID := c.GetString("user_id")

	var body struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&body) // optional body — a plain empty POST is still valid

	if err := h.consultSvc.DeclineScheduledByUser(c.Request.Context(), c.Param("id"), userID, body.Reason); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"status": "rejected"})
}

// Upcoming - GET /consultations/upcoming. Technician's scheduled/confirmed
// consultations — distinct from Pending (which is the urgent "ringing right now"
// queue). Powers an "Upcoming Consultations" list on the technician side.
func (h *ConsultationHandler) Upcoming(c *gin.Context) {
	userID := c.GetString("user_id")
	result, err := h.consultSvc.UpcomingForUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, result)
}

// Start - POST /consultations/:id/start.
func (h *ConsultationHandler) Start(c *gin.Context) {
	if err := h.consultSvc.MarkStarted(c.Request.Context(), c.Param("id")); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"status": "in_call"})
}

// End - POST /consultations/:id/end.
func (h *ConsultationHandler) End(c *gin.Context) {
	var body struct {
		ReconnectCount    int    `json:"reconnect_count"`
		ConnectionQuality string `json:"connection_quality"`
	}
	_ = c.ShouldBindJSON(&body)

	result, err := h.consultSvc.EndWithStats(c.Request.Context(), c.Param("id"), body.ReconnectCount, body.ConnectionQuality)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, result)
}

// CallInfo - GET /consultations/:id/call.
func (h *ConsultationHandler) CallInfo(c *gin.Context) {
	userID := c.GetString("user_id")

	result, err := h.consultSvc.Get(c.Request.Context(), c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if result == nil {
		utils.Error(c, http.StatusNotFound, "consultation not found")
		return
	}

	servers := []utils.IceServer{}
	if len(h.stunURLs) > 0 {
		servers = append(servers, utils.IceServer{URLs: h.stunURLs})
	}
	if h.turnURL != "" && h.turnSecret != "" {
		username, credential, _ := utils.GenerateTurnCredentials(h.turnSecret, userID, h.turnTTL)
		servers = append(servers, utils.IceServer{URLs: []string{h.turnURL}, Username: username, Credential: credential})
	}

	utils.Success(c, http.StatusOK, gin.H{
		"consultation": result,
		"room_id":      result.ID,
		"ice_servers":  servers,
	})
}

// Cancel - POST /consultations/:id/cancel.
func (h *ConsultationHandler) Cancel(c *gin.Context) {
	userID := c.GetString("user_id")
	if err := h.consultSvc.Cancel(c.Request.Context(), c.Param("id"), userID); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"status": "cancelled"})
}

// Pending - GET /consultations/pending.
func (h *ConsultationHandler) Pending(c *gin.Context) {
	userID := c.GetString("user_id")
	result, err := h.consultSvc.PendingForUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, result)
}

// Rating - POST /consultations/:id/rating.
func (h *ConsultationHandler) Rating(c *gin.Context) {
	userID := c.GetString("user_id")

	var body struct {
		Rating  int    `json:"rating" binding:"required,min=1,max=5"`
		Comment string `json:"comment"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.consultSvc.Rate(c.Request.Context(), c.Param("id"), userID, body.Rating, body.Comment); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"status": "rated"})
}

// Pay - POST /consultations/:id/payment.
func (h *ConsultationHandler) Pay(c *gin.Context) {
	if err := h.consultSvc.MarkPaid(c.Request.Context(), c.Param("id")); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"payment_status": "paid"})
}

// Escalate - POST /consultations/:id/escalate. "Book a slot" step after a video
// call: address_id is always required; scheduled_at is optional — omitted/absent
// means "ASAP" (technician comes as soon as possible), present means the customer
// picked a specific date/time slot for the on-site visit.
func (h *ConsultationHandler) Escalate(c *gin.Context) {
	var body struct {
		AddressID          string     `json:"address_id" binding:"required"`
		ProblemDescription string     `json:"problem_description"`
		ScheduledAt        *time.Time `json:"scheduled_at"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	booking, err := h.consultSvc.Escalate(c.Request.Context(), c.Param("id"), body.AddressID, body.ProblemDescription, body.ScheduledAt)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, booking)
}

// Mine - GET /consultations/mine. Customer's own consultation history (all
// statuses — the app's history screen splits these into tabs client-side).
func (h *ConsultationHandler) Mine(c *gin.Context) {
	userID := c.GetString("user_id")
	result, err := h.consultSvc.MyConsultations(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, result)
}
