package middleware

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/cache"
	"homefix-backend/internal/utils"
)

// RateLimit throttles brute-forceable endpoints (login, signup, OTP request) per
// client IP: at most `limit` requests per `window`. Backed by Redis (internal/cache)
// so the limit holds across multiple backend instances, not just in one process's
// memory. Fails open (allows the request) if Redis is unreachable — see
// cache.Client's doc comment.
func RateLimit(rdb *cache.Client, name string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := fmt.Sprintf("ratelimit:%s:%s", name, c.ClientIP())
		if !rdb.Allow(c.Request.Context(), key, limit, window) {
			utils.Error(c, http.StatusTooManyRequests, "too many attempts — please try again later")
			c.Abort()
			return
		}
		c.Next()
	}
}