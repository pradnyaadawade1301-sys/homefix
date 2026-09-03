package utils

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

// GenerateOTP returns a cryptographically random 6-digit numeric code (as used by
// AuthService.RequestOTP for phone signup/login).
func GenerateOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}