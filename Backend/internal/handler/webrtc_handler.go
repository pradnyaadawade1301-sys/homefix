package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/utils"
)

// WebRTCHandler hands out ICE server configuration (STUN + short-lived TURN
// credentials) for the peer-to-peer video call. It never touches call media or
// signaling itself — see CallHandler for that.
type WebRTCHandler struct {
	stunURLs   []string
	turnURL    string
	turnSecret string
	turnTTL    time.Duration
}

func NewWebRTCHandler(stunURLs []string, turnURL, turnSecret string, turnTTLSeconds int) *WebRTCHandler {
	return &WebRTCHandler{
		stunURLs:   stunURLs,
		turnURL:    turnURL,
		turnSecret: turnSecret,
		turnTTL:    time.Duration(turnTTLSeconds) * time.Second,
	}
}

// IceServers — GET /webrtc/ice-servers. Called by the app right before joining a
// call. Always includes public STUN (works for the common case where both peers
// aren't behind symmetric NAT); includes TURN with a freshly minted, time-limited
// credential only when TURN_URL/TURN_SECRET are configured, so calls still work
// (falling back to STUN-only / best-effort P2P) in environments that haven't set up
// a TURN relay yet.
func (h *WebRTCHandler) IceServers(c *gin.Context) {
	userID := c.GetString("user_id")

	servers := []utils.IceServer{}
	if len(h.stunURLs) > 0 {
		servers = append(servers, utils.IceServer{URLs: h.stunURLs})
	}

	if h.turnURL != "" && h.turnSecret != "" {
		username, credential, expiresAt := utils.GenerateTurnCredentials(h.turnSecret, userID, h.turnTTL)
		servers = append(servers, utils.IceServer{
			URLs:       []string{h.turnURL},
			Username:   username,
			Credential: credential,
		})
		utils.Success(c, http.StatusOK, gin.H{"ice_servers": servers, "expires_at": expiresAt})
		return
	}

	utils.Success(c, http.StatusOK, gin.H{"ice_servers": servers})
}
