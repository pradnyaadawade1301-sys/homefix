package utils

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"time"
)

// IceServer mirrors the shape flutter_webrtc / the browser RTCPeerConnection API
// expects for RTCIceServer: {urls, username, credential}.
type IceServer struct {
	URLs       []string `json:"urls"`
	Username   string   `json:"username,omitempty"`
	Credential string   `json:"credential,omitempty"`
}

// GenerateTurnCredentials implements the coturn "REST API" time-limited credential
// scheme (use-auth-secret): username is "<expiry-unix-ts>:<userID>", credential is
// base64(HMAC-SHA1(secret, username)). coturn derives the same credential itself from
// its own copy of the shared secret, so nothing long-lived is ever handed to the
// client — each call gets a fresh, short-lived TURN credential instead of a static
// password baked into the app.
func GenerateTurnCredentials(secret, userID string, ttl time.Duration) (username, credential string, expiresAt time.Time) {
	expiresAt = time.Now().Add(ttl)
	username = fmt.Sprintf("%d:%s", expiresAt.Unix(), userID)

	mac := hmac.New(sha1.New, []byte(secret))
	mac.Write([]byte(username))
	credential = base64.StdEncoding.EncodeToString(mac.Sum(nil))

	return username, credential, expiresAt
}
