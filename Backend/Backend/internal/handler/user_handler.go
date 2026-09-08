package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/models"
	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type UserHandler struct {
	userService *service.UserService
}

func NewUserHandler(userService *service.UserService) *UserHandler {
	return &UserHandler{userService: userService}
}

func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := c.GetString("user_id")
	u, err := h.userService.GetProfile(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	if u == nil {
		utils.Error(c, http.StatusNotFound, "user not found")
		return
	}
	utils.Success(c, http.StatusOK, u)
}

type updateProfileBody struct {
	Name  string  `json:"name" binding:"required"`
	Email *string `json:"email"`
}

func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID := c.GetString("user_id")
	var body updateProfileBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.userService.UpdateProfile(c.Request.Context(), userID, body.Name, body.Email); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "profile updated"})
}

type updatePhotoBody struct {
	// PhotoURL is the "url" returned by POST /api/v1/uploads. Send null/omit to remove
	// the current photo and fall back to the name-initial avatar in the app.
	PhotoURL *string `json:"photo_url"`
}

// UpdatePhoto sets the caller's avatar shown in the app header and profile screen.
// Flutter flow: upload the picked image via POST /api/v1/uploads, then call this with
// the returned url.
func (h *UserHandler) UpdatePhoto(c *gin.Context) {
	userID := c.GetString("user_id")
	var body updatePhotoBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.userService.UpdatePhotoURL(c.Request.Context(), userID, body.PhotoURL); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "photo updated"})
}

type fcmTokenBody struct {
	Token string `json:"token" binding:"required"`
}

func (h *UserHandler) RegisterFCMToken(c *gin.Context) {
	userID := c.GetString("user_id")
	var body fcmTokenBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.userService.RegisterFCMToken(c.Request.Context(), userID, body.Token); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "fcm token registered"})
}

func (h *UserHandler) AddAddress(c *gin.Context) {
	userID := c.GetString("user_id")
	var a models.Address
	if err := c.ShouldBindJSON(&a); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	a.UserID = userID
	created, err := h.userService.AddAddress(c.Request.Context(), &a)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, created)
}

func (h *UserHandler) ListAddresses(c *gin.Context) {
	userID := c.GetString("user_id")
	addrs, err := h.userService.ListAddresses(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, addrs)
}