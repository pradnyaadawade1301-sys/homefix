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
	// CategoryIDs is the new multi-category field — a technician can select more
	// than one service (e.g. Plumbing + Painting). CategoryID (singular) is still
	// accepted for backward compatibility with any client not yet updated; if
	// CategoryIDs is empty it's used as a single-item fallback.
	CategoryIDs     []string `json:"category_ids"`
	CategoryID      string   `json:"category_id"`
	ExperienceYears int      `json:"experience_years"`
	Address         string   `json:"address" binding:"required"`
	GovernmentIDURL string   `json:"government_id_url" binding:"required"`
	ProfilePhotoURL string   `json:"profile_photo_url" binding:"required"`
}

type updateTechCategoriesBody struct {
	CategoryIDs []string `json:"category_ids" binding:"required"`
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
	categoryIDs := body.CategoryIDs
	if len(categoryIDs) == 0 && body.CategoryID != "" {
		categoryIDs = []string{body.CategoryID}
	}
	if len(categoryIDs) == 0 {
		utils.Error(c, http.StatusBadRequest, "select at least one category")
		return
	}
	t, err := h.techService.RegisterTechnician(c.Request.Context(), userID, categoryIDs, body.ExperienceYears,
		body.Address, body.GovernmentIDURL, body.ProfilePhotoURL)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, t)
}

// UpdateCategories - PUT /technicians/me/categories. Lets an already-registered
// technician change which categories they serve (e.g. add Painting to an
// existing Plumbing profile) from their profile screen.
func (h *TechnicianHandler) UpdateCategories(c *gin.Context) {
	userID := c.GetString("user_id")
	me, err := h.techService.GetByUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if me == nil {
		utils.Error(c, http.StatusNotFound, "technician profile not found")
		return
	}
	var body updateTechCategoriesBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	categoryIDs, err := h.techService.UpdateCategories(c.Request.Context(), me.ID, body.CategoryIDs)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"category_ids": categoryIDs})
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
	// The base Technician scan doesn't include the technician_categories
	// join, so the Manage Categories screen (which needs to pre-check the
	// technician's current categories, not just show names) can't rely on
	// it — fetch the id list separately and attach it as an extra field.
	// Populated here only (not persisted/scanned from the DB row), and kept
	// on the same flat object so this stays a drop-in-compatible response
	// for every existing caller of GET /technicians/me.
	categoryIDs, err := h.techService.GetCategoryIDs(c.Request.Context(), t.ID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	t.CategoryIDs = categoryIDs
	utils.Success(c, http.StatusOK, t)
}

type technicianPhotoBody struct {
	// Empty string removes the photo (falls back to the name-initial avatar
	// in the app) — same convention as UpdatePhoto on the user profile.
	PhotoURL string `json:"photo_url"`
}

// UpdatePhoto lets a technician change or remove the profile photo they set
// once during KYC registration — RegisterTechnician only ever sets it at
// signup, so without this endpoint there was no way to change it afterwards.
func (h *TechnicianHandler) UpdatePhoto(c *gin.Context) {
	userID := c.GetString("user_id")
	var body technicianPhotoBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.techService.UpdateProfilePhoto(c.Request.Context(), userID, body.PhotoURL); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "photo updated"})
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

type verifiedBadgeBody struct {
	Verified bool `json:"verified"`
}

// SetVerifiedBadge — PATCH /technicians/:id/verified-badge, admin-only.
// Unlike SetAvailability this has no "must be your own row" check since
// only an admin (RequireRole("admin")) can reach it at all.
func (h *TechnicianHandler) SetVerifiedBadge(c *gin.Context) {
	technicianID := c.Param("id")
	var body verifiedBadgeBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.techService.SetVerifiedBadge(c.Request.Context(), technicianID, body.Verified); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "verified badge updated"})
}

type workingHoursBody struct {
	WorkingHours models.WorkingHours `json:"working_hours" binding:"required"`
}

// SetWorkingHours lets a technician set their own weekly schedule (display-only
// — it doesn't gate matching or booking). Like SetAvailability, a technician
// can only update their OWN row.
func (h *TechnicianHandler) SetWorkingHours(c *gin.Context) {
	userID := c.GetString("user_id")
	technicianID := c.Param("id")

	self, err := h.techService.GetByUser(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if self == nil || self.ID != technicianID {
		utils.Error(c, http.StatusForbidden, "you can only update your own working hours")
		return
	}

	var body workingHoursBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.techService.UpdateWorkingHours(c.Request.Context(), technicianID, body.WorkingHours); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "working hours updated"})
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
