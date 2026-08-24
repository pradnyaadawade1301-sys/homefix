package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

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
