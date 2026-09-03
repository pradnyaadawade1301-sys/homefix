package utils

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestHashAndCheckPassword(t *testing.T) {
	hash, err := HashPassword("correct-horse-battery-staple")
	require.NoError(t, err)
	assert.NotEqual(t, "correct-horse-battery-staple", hash, "hash must never equal the plaintext")

	assert.True(t, CheckPassword("correct-horse-battery-staple", hash))
	assert.False(t, CheckPassword("wrong-password", hash))
}

func TestHashPassword_DifferentSaltsPerCall(t *testing.T) {
	h1, err := HashPassword("same-password")
	require.NoError(t, err)
	h2, err := HashPassword("same-password")
	require.NoError(t, err)

	assert.NotEqual(t, h1, h2, "bcrypt must salt each hash independently")
	assert.True(t, CheckPassword("same-password", h1))
	assert.True(t, CheckPassword("same-password", h2))
}