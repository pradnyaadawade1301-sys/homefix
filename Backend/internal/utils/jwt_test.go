package utils

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAccessToken_RoundTrip(t *testing.T) {
	token, err := GenerateAccessToken("user-123", "customer", "test-secret", 15)
	require.NoError(t, err)

	claims, err := ParseAccessToken(token, "test-secret")
	require.NoError(t, err)
	assert.Equal(t, "user-123", claims.UserID)
	assert.Equal(t, "customer", claims.Role)
}

func TestAccessToken_RejectsWrongSecret(t *testing.T) {
	token, err := GenerateAccessToken("user-123", "customer", "secret-a", 15)
	require.NoError(t, err)

	_, err = ParseAccessToken(token, "secret-b")
	assert.Error(t, err, "a token signed with a different secret must not verify")
}

func TestAccessToken_RejectsExpired(t *testing.T) {
	// TTL of 0 minutes: NumericDate(now) already at/just past expiry by the time
	// ParseAccessToken runs.
	token, err := GenerateAccessToken("user-123", "customer", "test-secret", 0)
	require.NoError(t, err)

	time.Sleep(1100 * time.Millisecond) // jwt exp has whole-second granularity
	_, err = ParseAccessToken(token, "test-secret")
	assert.Error(t, err, "an expired token must not verify")
}

func TestRefreshToken_RoundTrip(t *testing.T) {
	token, err := GenerateRefreshToken("user-456", "refresh-secret", 24)
	require.NoError(t, err)

	userID, err := ParseRefreshToken(token, "refresh-secret")
	require.NoError(t, err)
	assert.Equal(t, "user-456", userID)
}

func TestRefreshToken_RejectsWrongSecret(t *testing.T) {
	token, err := GenerateRefreshToken("user-456", "secret-a", 24)
	require.NoError(t, err)

	_, err = ParseRefreshToken(token, "secret-b")
	assert.Error(t, err)
}
