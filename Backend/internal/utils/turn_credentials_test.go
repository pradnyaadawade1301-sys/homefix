package utils

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGenerateTurnCredentials_MatchesCoturnScheme(t *testing.T) {
	secret := "shared-secret"
	userID := "user-789"
	ttl := time.Hour

	username, credential, expiresAt := GenerateTurnCredentials(secret, userID, ttl)

	// username must be "<unix-expiry>:<userID>" per coturn's use-auth-secret scheme.
	parts := strings.SplitN(username, ":", 2)
	require.Len(t, parts, 2)
	assert.Equal(t, userID, parts[1])

	expiryUnix, err := strconv.ParseInt(parts[0], 10, 64)
	require.NoError(t, err)
	assert.WithinDuration(t, expiresAt, time.Unix(expiryUnix, 0), time.Second)
	assert.WithinDuration(t, time.Now().Add(ttl), expiresAt, 2*time.Second)

	// credential must be base64(HMAC-SHA1(secret, username)) — coturn derives the
	// same value independently from its own copy of the secret to authenticate.
	mac := hmac.New(sha1.New, []byte(secret))
	mac.Write([]byte(username))
	expectedCredential := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	assert.Equal(t, expectedCredential, credential)
}

func TestGenerateTurnCredentials_DifferentUsersGetDifferentCredentials(t *testing.T) {
	_, credA, _ := GenerateTurnCredentials("secret", "user-a", time.Hour)
	_, credB, _ := GenerateTurnCredentials("secret", "user-b", time.Hour)
	assert.NotEqual(t, credA, credB)
}