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
func (h *ConsultationHandler) Request(c *gin.Context) {
    userID := c.GetString("user_id")

    var body struct {
        CategoryID            string   `json:"category_id" binding:"required"`
        PreferredTechnicianID string   `json:"preferred_technician_id"`
        Latitude              *float64 `json:"latitude"`
        Longitude             *float64 `json:"longitude"`
    }
    if err := c.ShouldBindJSON(&body); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    result, err := h.consultSvc.Request(c.Request.Context(), userID, body.CategoryID, body.PreferredTechnicianID, body.Latitude, body.Longitude)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, err.Error())
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

// Accept - POST /consultations/:id/accept. Technician accepts the incoming request.
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
func (h *ConsultationHandler) Reject(c *gin.Context) {
    userID := c.GetString("user_id")
    if err := h.consultSvc.RejectByUser(c.Request.Context(), c.Param("id"), userID); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }
    utils.Success(c, http.StatusOK, gin.H{"status": "rejected"})
}

// Start - POST /consultations/:id/start.
func (h *ConsultationHandler) Start(c *gin.Context) {
    userID := c.GetString("user_id")
    if err := h.consultSvc.MarkStarted(c.Request.Context(), c.Param("id"), userID); err != nil {
        utils.Error(c, http.StatusForbidden, err.Error())
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
    userID := c.GetString("user_id")
    if err := h.consultSvc.MarkPaid(c.Request.Context(), c.Param("id"), userID); err != nil {
        utils.Error(c, http.StatusForbidden, err.Error())
        return
    }
    utils.Success(c, http.StatusOK, gin.H{"payment_status": "paid"})
}

// Escalate - POST /consultations/:id/escalate.
func (h *ConsultationHandler) Escalate(c *gin.Context) {
    var body struct {
        AddressID          string `json:"address_id" binding:"required"`
        ProblemDescription string `json:"problem_description"`
    }
    if err := c.ShouldBindJSON(&body); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }
    booking, err := h.consultSvc.Escalate(c.Request.Context(), c.Param("id"), body.AddressID, body.ProblemDescription)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, err.Error())
        return
    }
    utils.Success(c, http.StatusCreated, booking)
}