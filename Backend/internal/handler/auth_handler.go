package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/service"
	"homefix-backend/internal/utils"
)

type AuthHandler struct {
	authService *service.AuthService
	env         string
}

func NewAuthHandler(authService *service.AuthService, env string) *AuthHandler {
	return &AuthHandler{authService: authService, env: env}
}

type requestOTPBody struct {
	Phone string `json:"phone" binding:"required"`
}

func (h *AuthHandler) RequestOTP(c *gin.Context) {
	var body requestOTPBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	otp, err := h.authService.RequestOTP(c.Request.Context(), body.Phone)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}

	// The OTP must never be returned in the API response, in any environment —
	// doing so makes the OTP flow trivially bypassable. It is only ever sent
	// via the actual SMS channel.
	_ = otp
	resp := gin.H{"message": "OTP sent"}
	utils.Success(c, http.StatusOK, resp)
}

type verifyOTPBody struct {
	Phone string `json:"phone" binding:"required"`
	OTP   string `json:"otp" binding:"required"`
}

func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var body verifyOTPBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	u, access, refresh, err := h.authService.VerifyOTP(c.Request.Context(), body.Phone, body.OTP)
	if err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"user": u, "access_token": access, "refresh_token": refresh})
}

type loginBody struct {
	Identifier string `json:"identifier" binding:"required"` // email or phone
	Password   string `json:"password" binding:"required"`
}

func (h *AuthHandler) Login(c *gin.Context) {
	var body loginBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	u, access, refresh, err := h.authService.LoginWithPassword(c.Request.Context(), body.Identifier, body.Password)
	if err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"user": u, "access_token": access, "refresh_token": refresh})
}

type signupBody struct {
	Name string `json:"name" binding:"required"`
	// Email is mandatory (not just optional) since every new account must go
	// through email verification (see VerifyEmailScreen on the Flutter side).
	Email string `json:"email" binding:"required,email"`
	// Phone is no longer collected on the signup screen (removed for both
	// customer and technician). It's optional here; AuthService.SignupWithPassword
	// fills in a unique internal placeholder when it's blank, since the phone
	// column is still NOT NULL UNIQUE. NOTE: features that call the phone
	// column directly — calling a technician/customer from a job, phone-based
	// OTP login — won't have a real number to use until the person adds one
	// later (e.g. from Personal Information, once that supports phone again).
	Phone    string `json:"phone"`
	Password string `json:"password" binding:"required,min=6"`
	Role     string `json:"role"` // "customer" or "technician"
}

func (h *AuthHandler) Signup(c *gin.Context) {
	var body signupBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	u, access, refresh, err := h.authService.SignupWithPassword(
		c.Request.Context(), body.Name, body.Email, body.Phone, body.Password, body.Role)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusCreated, gin.H{"user": u, "access_token": access, "refresh_token": refresh})
}

type setPasswordBody struct {
	Password string `json:"password" binding:"required,min=6"`
}

func (h *AuthHandler) SetPassword(c *gin.Context) {
	userID := c.GetString("user_id")
	var body setPasswordBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.authService.SetPassword(c.Request.Context(), userID, body.Password); err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "password set"})
}

type changePasswordBody struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required,min=6"`
}

// ChangePassword backs the "Change Password" screen under Personal
// Information: the caller must supply their current password, which is
// verified before the new one is written.
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	userID := c.GetString("user_id")
	var body changePasswordBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.authService.ChangePassword(c.Request.Context(), userID, body.CurrentPassword, body.NewPassword); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "password changed"})
}

type refreshBody struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

func (h *AuthHandler) Refresh(c *gin.Context) {
	var body refreshBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	access, refresh, err := h.authService.RefreshTokens(c.Request.Context(), body.RefreshToken)
	if err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"access_token": access, "refresh_token": refresh})
}

func (h *AuthHandler) Logout(c *gin.Context) {
	// Stateless JWT: logout is handled client-side by discarding tokens.
	// (A refresh-token blocklist table can be added later if server-side revocation is needed.)
	utils.Success(c, http.StatusOK, gin.H{"message": "logged out"})
}

type requestEmailOTPBody struct {
	Email string `json:"email" binding:"required,email"`
}

// RequestEmailOTP sends a 6-digit verification code to the given email — used for
// the "verify your email" step shown right after signup.
func (h *AuthHandler) RequestEmailOTP(c *gin.Context) {
	var body requestEmailOTPBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	otp, err := h.authService.RequestEmailOTP(c.Request.Context(), body.Email)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	// Same as phone OTP — never echo the OTP back in the response, in any
	// environment. It is only ever delivered via the actual email channel.
	_ = otp
	resp := gin.H{"message": "OTP sent to your email"}
	utils.Success(c, http.StatusOK, resp)
}

type verifyEmailOTPBody struct {
	Email string `json:"email" binding:"required,email"`
	OTP   string `json:"otp" binding:"required"`
}

func (h *AuthHandler) VerifyEmailOTP(c *gin.Context) {
	var body verifyEmailOTPBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.authService.VerifyEmailOTP(c.Request.Context(), body.Email, body.OTP); err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "email verified"})
}

type googleLoginBody struct {
	// IDToken is GoogleSignInAuthentication.idToken from the Flutter
	// google_sign_in package — NOT the accessToken.
	IDToken string `json:"id_token" binding:"required"`
	Role    string `json:"role"` // "customer" or "technician"; ignored if the account already exists
}
type forgotPasswordBody struct {
	Email string `json:"email" binding:"required,email"`
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var body forgotPasswordBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.authService.RequestPasswordReset(c.Request.Context(), body.Email); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "reset code sent"})
}

type resetPasswordBody struct {
	Email       string `json:"email" binding:"required,email"`
	OTP         string `json:"otp" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var body resetPasswordBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.authService.ResetPassword(c.Request.Context(), body.Email, body.OTP, body.NewPassword); err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"message": "password reset successful"})
}

// LoginWithGoogle is "Continue with Google" — POST /auth/google. Verifies
// the ID token server-side and finds-or-creates the user, returning the
// same {user, access_token, refresh_token} shape as password Login so the
// Flutter side handles both identically.
func (h *AuthHandler) LoginWithGoogle(c *gin.Context) {
	var body googleLoginBody
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	u, access, refresh, err := h.authService.LoginWithGoogle(c.Request.Context(), body.IDToken, body.Role)
	if err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	utils.Success(c, http.StatusOK, gin.H{"user": u, "access_token": access, "refresh_token": refresh})
}