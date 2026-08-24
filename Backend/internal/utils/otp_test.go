package utils

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGenerateOTP_IsSixDigits(t *testing.T) {
	for i := 0; i < 50; i++ {
		otp, err := GenerateOTP()
		require.NoError(t, err)
		assert.Len(t, otp, 6)
		for _, r := range otp {
			assert.True(t, r >= '0' && r <= '9', "OTP must be all digits, got %q", otp)
		}
	}
}

func TestGenerateOTP_IsRandom(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 30; i++ {
		otp, err := GenerateOTP()
		require.NoError(t, err)
		seen[otp] = true
	}
	// Extremely unlikely all 30 six-digit OTPs collide if generation is truly random.
	assert.Greater(t, len(seen), 1)
}
