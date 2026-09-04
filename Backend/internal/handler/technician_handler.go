package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/models"
	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type TechnicianHandler struct {
	techService *service.TechnicianService
}

func NewTechnicianHandler(techService *service.TechnicianService) *TechnicianHandler {
	return &TechnicianHandler{techService: techService}
}

type registerTechBody struct {
	CategoryID      string `json:"category_id" binding:"required"`
	ExperienceYears int    `json:"experience_years"`
	Address         string `json:"address" binding:"required"`
	GovernmentIDURL string `json:"government_id_url" binding:"required"`
	ProfilePhotoURL string `json:"profile_photo_url" binding:"required"`
}

// List is the public, unauthenticated technician browse endpoint — optionally filtered
// by ?category_id=. Used by the home screen's technician cards.
func (h *TechnicianHandler) List(c *gin.Context) {
	categoryID := c.Query("category_id")
	techs, err := h.techService.ListPublic(c.Request.Context(), categoryID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if techs == nil {
		techs = []models.TechnicianPublic{}
	}
	utils.Success(c, http.StatusOK, techs)
}

// GetByID is the public technician detail endpoint.
func (h *TechnicianHandler) GetByID(c *gin.Context) {
	id := c.Param("id")
	t, err := h.techService.GetPublicByID(c.Request.Context(), id)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if t == nil {
		utils.Error(c, http.StatusNotFound, "technician not found")
		return
	}
	utils.Success(c, http.StatusOK, t)
}

func (h *TechnicianHandler) Register(c *gin.Context) {
	userID := c.GetString("user_id")
	var body registerTechBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	t, err := h.techService.RegisterTechnician(c.Request.Context(), userID, body.CategoryID, body.ExperienceYears,
		body.Address, body.GovernmentIDURL, body.ProfilePhotoURL)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, t)
}

func (h *TechnicianHandler) Me(c *gin.Context) {
	userID := c.GetString("user_id")
	t, err := h.techService.GetByUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if t == nil {
		utils.Error(c, http.StatusNotFound, "technician profile not found")
		return
	}
	utils.Success(c, http.StatusOK, t)
}

func (h *TechnicianHandler) FindAvailable(c *gin.Context) {
	categoryID := c.Query("category_id")
	if categoryID == "" {
		utils.Error(c, http.StatusBadRequest, "category_id is required")
		return
	}
	var lat, lng *float64
	if latStr := c.Query("lat"); latStr != "" {
		if v, err := strconv.ParseFloat(latStr, 64); err == nil {
			lat = &v
		}
	}
	if lngStr := c.Query("lng"); lngStr != "" {
		if v, err := strconv.ParseFloat(lngStr, 64); err == nil {
			lng = &v
		}
	}
	var radiusKm *float64
	if radiusStr := c.Query("radius_km"); radiusStr != "" {
		if v, err := strconv.ParseFloat(radiusStr, 64); err == nil {
			radiusKm = &v
		}
	}
	techs, err := h.techService.FindAvailable(c.Request.Context(), categoryID, lat, lng, radiusKm)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if techs == nil {
		techs = []models.TechnicianNearby{}
	}
	utils.Success(c, http.StatusOK, techs)
}

type availabilityBody struct {
	Available bool `json:"available"`
}

func (h *TechnicianHandler) SetAvailability(c *gin.Context) {
	userID := c.GetString("user_id")
	technicianID := c.Param("id")

	// Verify the caller is toggling their OWN availability, not some other
	// technician's — this endpoint only requires role=technician, so without
	// this check any technician could flip any other technician online/
	// offline just by knowing their id.
	self, err := h.techService.GetByUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if self == nil || self.ID != technicianID {
		utils.Error(c, http.StatusForbidden, "you can only update your own availability")
		return
	}

	var body availabilityBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.techService.SetAvailability(c.Request.Context(), technicianID, body.Available); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "availability updated"})
}

type locationBody struct {
	Lat float64 `json:"lat" binding:"required"`
	Lng float64 `json:"lng" binding:"required"`
}

func (h *TechnicianHandler) UpdateLocation(c *gin.Context) {
	technicianID := c.Param("id")
	var body locationBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.techService.UpdateLocation(c.Request.Context(), technicianID, body.Lat, body.Lng); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "location updated"})
}

type verifyBody struct {
	Status string `json:"status" binding:"required"` // "approved" or "rejected"
	Reason string `json:"reason"`                    // required in practice when rejecting
}

// Verify is the admin approve/reject action for a technician's KYC submission.
func (h *TechnicianHandler) Verify(c *gin.Context) {
	technicianID := c.Param("id")
	var body verifyBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.techService.Verify(c.Request.Context(), technicianID, body.Status, body.Reason); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "approval status updated", "status": body.Status})
}

func (h *TechnicianHandler) Reviews(c *gin.Context) {
	technicianID := c.Param("id")
	reviews, err := h.techService.Reviews(c.Request.Context(), technicianID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, reviews)
}
