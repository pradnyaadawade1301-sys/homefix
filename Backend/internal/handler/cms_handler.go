package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

// CmsHandler is the PUBLIC (no auth) read side of the CMS module — About Us,
// Privacy Policy, Terms, Help Center, FAQs, active announcements and banners.
// Writes only ever happen from the hidden /admin panel (internal/admin/cms.go).
type CmsHandler struct {
	svc *service.CmsService
}

func NewCmsHandler(svc *service.CmsService) *CmsHandler {
	return &CmsHandler{svc: svc}
}

func (h *CmsHandler) GetPage(c *gin.Context) {
	page, err := h.svc.GetPage(c.Request.Context(), c.Param("key"))
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if page == nil {
		utils.Error(c, http.StatusNotFound, "page not found")
		return
	}
	utils.Success(c, http.StatusOK, page)
}

func (h *CmsHandler) ListFaqs(c *gin.Context) {
	list, err := h.svc.ListFaqs(c.Request.Context(), true)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}

func (h *CmsHandler) ListAnnouncements(c *gin.Context) {
	list, err := h.svc.ListAnnouncements(c.Request.Context(), true)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}

func (h *CmsHandler) ListBanners(c *gin.Context) {
	list, err := h.svc.ListBanners(c.Request.Context(), true)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, list)
}