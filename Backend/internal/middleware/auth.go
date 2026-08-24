package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/utils"
)

func JWTAuth(accessSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" || !strings.HasPrefix(header, "Bearer ") {
			utils.Error(c, http.StatusUnauthorized, "missing or malformed authorization header")
			c.Abort()
			return
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")
		claims, err := utils.ParseAccessToken(tokenStr, accessSecret)
		if err != nil {
			utils.Error(c, http.StatusUnauthorized, "invalid or expired token")
			c.Abort()
			return
		}
		c.Set("user_id", claims.UserID)
		c.Set("role", claims.Role)
		c.Next()
	}
}

// RequireRole restricts a route to one or more roles (e.g. "admin", "technician").
func RequireRole(roles ...string) gin.HandlerFunc {
	allowed := make(map[string]bool)
	for _, r := range roles {
		allowed[r] = true
	}
	return func(c *gin.Context) {
		role, _ := c.Get("role")
		roleStr, _ := role.(string)
		if !allowed[roleStr] {
			utils.Error(c, http.StatusForbidden, "insufficient permissions for this action")
			c.Abort()
			return
		}
		c.Next()
	}
}
