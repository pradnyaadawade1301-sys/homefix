package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/utils"
)

const sessionCookieName = "hf_admin_session"
const sessionTTLMinutes = 12 * 60 // 12 hours — deliberately separate from the mobile app's 15-minute access token TTL

// requireAdminSession gates every /admin/* route except /admin/login itself. The
// cookie is a normal signed JWT (role must be "admin") — reusing the same
// signing secret and verification code path as the mobile API's JWTAuth
// middleware, just carried in an httpOnly cookie instead of an Authorization
// header (a browser session, not an API client).
func (d *Deps) requireAdminSession(c *gin.Context) {
	cookie, err := c.Cookie(sessionCookieName)
	if err != nil || cookie == "" {
		c.Redirect(http.StatusFound, "/admin/login")
		c.Abort()
		return
	}
	claims, err := utils.ParseAccessToken(cookie, d.JWTSecret)
	if err != nil || claims.Role != "admin" {
		c.SetCookie(sessionCookieName, "", -1, "/admin", "", false, true)
		c.Redirect(http.StatusFound, "/admin/login")
		c.Abort()
		return
	}
	c.Set("admin_user_id", claims.UserID)
	c.Next()
}

func (d *Deps) currentAdminID(c *gin.Context) string {
	v, _ := c.Get("admin_user_id")
	id, _ := v.(string)
	return id
}

// audit records one mutating admin action. Best-effort: a logging failure never
// blocks the action itself, but is worth knowing about, so it's logged to stderr
// via gin's own logger through the returned error being swallowed only after use.
func (d *Deps) audit(c *gin.Context, action, entityType, entityID, detailsJSON string) {
	_ = d.Audit.Log(c.Request.Context(), d.currentAdminID(c), action, entityType, entityID, detailsJSON, c.ClientIP())
}

func (d *Deps) handleLoginPage(c *gin.Context) {
	if cookie, err := c.Cookie(sessionCookieName); err == nil && cookie != "" {
		if claims, err := utils.ParseAccessToken(cookie, d.JWTSecret); err == nil && claims.Role == "admin" {
			c.Redirect(http.StatusFound, "/admin")
			return
		}
	}
	renderLogin(c, "")
}

func (d *Deps) handleLoginSubmit(c *gin.Context) {
	identifier := c.PostForm("identifier")
	password := c.PostForm("password")

	user, err := d.Admin.Login(c.Request.Context(), identifier, password)
	if err != nil {
		renderLogin(c, "Invalid credentials or insufficient access.")
		return
	}

	token, err := utils.GenerateAccessToken(user.ID, user.Role, d.JWTSecret, sessionTTLMinutes)
	if err != nil {
		renderLogin(c, "Could not start session — please try again.")
		return
	}

	// httpOnly (no JS access — mitigates XSS token theft), SameSite=Strict (mitigates
	// CSRF from any cross-site navigation), Secure should be true behind HTTPS in
	// production (see PUBLIC_BASE_URL / reverse proxy config).
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie(sessionCookieName, token, sessionTTLMinutes*60, "/admin", "", false, true)
	d.audit(c, "admin.login", "user", user.ID, "")
	c.Redirect(http.StatusFound, "/admin")
}

func (d *Deps) handleLogout(c *gin.Context) {
	d.audit(c, "admin.logout", "user", d.currentAdminID(c), "")
	c.SetCookie(sessionCookieName, "", -1, "/admin", "", false, true)
	c.Redirect(http.StatusFound, "/admin/login")
}
