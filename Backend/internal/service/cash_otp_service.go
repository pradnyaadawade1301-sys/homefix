package service

import (
	"context"
	"errors"

	"homefix-backend/internal/repository"
)

// SetCashOtpRepo wires the Cash-on-Delivery confirmation OTP store.
func (s *RazorpayService) SetCashOtpRepo(r *repository.CashOtpRepository) { s.cashOtpRepo = r }

// GetCashOTP returns the OTP for the customer's own pending cash payment. If a
// payment was created before OTPs existed (or generation failed), one is
// generated on first view so the technician is never stuck.
func (s *RazorpayService) GetCashOTP(ctx context.Context, paymentID, userID string) (string, error) {
	if s.cashOtpRepo == nil {
		return "", errors.New("cash OTP is not enabled")
	}
	otp, found, err := s.cashOtpRepo.GetForCustomer(ctx, paymentID, userID)
	if err != nil {
		return "", err
	}
	if !found {
		return "", errors.New("no pending cash payment found")
	}
	if otp != "" {
		return otp, nil
	}
	otp = generateOTP()
	if err := s.cashOtpRepo.Set(ctx, paymentID, otp); err != nil {
		return "", err
	}
	return otp, nil
}

// RefreshCashOTP issues a new OTP (and clears the wrong-attempt lock). Only
// the payment's own customer can do this.
func (s *RazorpayService) RefreshCashOTP(ctx context.Context, paymentID, userID string) (string, error) {
	if s.cashOtpRepo == nil {
		return "", errors.New("cash OTP is not enabled")
	}
	_, found, err := s.cashOtpRepo.GetForCustomer(ctx, paymentID, userID)
	if err != nil {
		return "", err
	}
	if !found {
		return "", errors.New("no pending cash payment found")
	}
	otp := generateOTP()
	if err := s.cashOtpRepo.Set(ctx, paymentID, otp); err != nil {
		return "", err
	}
	return otp, nil
}
