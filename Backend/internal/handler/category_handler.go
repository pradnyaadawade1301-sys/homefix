package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/utils"
)

type CategoryHandler struct {
	catRepo *repository.CategoryRepository
}

func NewCategoryHandler(catRepo *repository.CategoryRepository) *CategoryHandler {
	return &CategoryHandler{catRepo: catRepo}
}

func (h *CategoryHandler) List(c *gin.Context) {
	cats, err := h.catRepo.List(c.Request.Context())
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, cats)
}

func (h *CategoryHandler) Create(c *gin.Context) {
	var cat models.Category
	if err := c.ShouldBindJSON(&cat); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	created, err := h.catRepo.Create(c.Request.Context(), &cat)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, created)
}

type updateWarrantyOptionsBody struct {
	WarrantyOptions []int32 `json:"warranty_options" binding:"required"`
}

// UpdateWarrantyOptions - PATCH /categories/:id/warranty-options (admin only).
// Sets the whitelist of warranty durations (days) technicians in this
// category may offer at job completion — see BookingService.Complete, which
// enforces every warranty a technician sets is one of these values.
func (h *CategoryHandler) UpdateWarrantyOptions(c *gin.Context) {
	id := c.Param("id")
	var body updateWarrantyOptionsBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if len(body.WarrantyOptions) == 0 {
		utils.Error(c, http.StatusBadRequest, "at least one warranty option is required")
		return
	}
	for _, d := range body.WarrantyOptions {
		if d <= 0 {
			utils.Error(c, http.StatusBadRequest, "warranty days must be positive")
			return
		}
	}
	if err := h.catRepo.UpdateWarrantyOptions(c.Request.Context(), id, body.WarrantyOptions); err != nil {
		if err == pgx.ErrNoRows {
			utils.Error(c, http.StatusNotFound, "category not found")
			return
		}
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "warranty options updated"})
}