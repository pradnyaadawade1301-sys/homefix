package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	razorpay "github.com/razorpay/razorpay-go"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// DueService is the COD commission ledger. When a technician collects cash the
// platform's commission becomes a "due"; COD jobs stop once dues cross the
// limit (or the oldest due is too old) until the technician pays them via
// Razorpay. Replaces the old wallet-balance gate.
type DueService struct {
	repo      *repository.DueRepository
	client    *razorpay.Client
	keyID     string
	keySecret string
	limit     float64
	maxDays   int
}

func NewDueService(repo *repository.DueRepository, keyID, keySecret string, limit float64, maxDays int) *DueService {
	return &DueService{repo: repo, client: razorpay.NewClient(keyID, keySecret), keyID: keyID, keySecret: keySecret, limit: limit, maxDays: maxDays}
}

// CheckCodAllowed refuses a new COD job when dues (plus this job's commission)
// would exceed the limit, or the oldest unpaid due is older than maxDays.
func (s *DueService) CheckCodAllowed(ctx context.Context, techUserID string, newCommission float64) error {
	total, oldest, err := s.repo.PendingStats(ctx, techUserID)
	if err != nil {
		return err
	}
	if reason := s.blockReason(total, oldest, newCommission); reason != "" {
		return errors.New(reason)
	}
	return nil
}

func (s *DueService) blockReason(total float64, oldest *time.Time, newCommission float64) string {
	if oldest != nil && s.maxDays > 0 && time.Since(*oldest) > time.Duration(s.maxDays)*24*time.Hour {
		return fmt.Sprintf("the technician has commission dues (₹%.2f) pending for more than %d days — ask them to clear dues, or pay online instead", total, s.maxDays)
	}
	if total+newCommission > s.limit {
		return fmt.Sprintf("the technician's pending commission dues (₹%.2f) have reached the cash limit (₹%.2f) — ask them to clear dues, or pay online instead", total, s.limit)
	}
	return ""
}

func (s *DueService) AddDue(ctx context.Context, techUserID, paymentID, bookingID string, amount float64) error {
	return s.repo.Create(ctx, techUserID, paymentID, bookingID, amount)
}

func (s *DueService) Summary(ctx context.Context, techUserID string) (*models.DueSummary, error) {
	total, oldest, err := s.repo.PendingStats(ctx, techUserID)
	if err != nil {
		return nil, err
	}
	dues, err := s.repo.List(ctx, techUserID, 50)
	if err != nil {
		return nil, err
	}
	reason := s.blockReason(total, oldest, 0)
	if total >= s.limit && reason == "" {
		reason = "cash limit reached"
	}
	return &models.DueSummary{
		PendingTotal: total, Limit: s.limit, MaxDays: s.maxDays,
		CodBlocked: reason != "", BlockedReason: reason, OldestDueAt: oldest, Dues: dues,
	}, nil
}

type DueOrder struct {
	OrderID     string  `json:"razorpay_order_id"`
	KeyID       string  `json:"razorpay_key_id"`
	AmountPaise int64   `json:"amount_paise"`
	Amount      float64 `json:"amount"`
	Currency    string  `json:"currency"`
}

// CreateSettlementOrder opens a Razorpay order for ALL pending dues, or only
// for dueID when given (the per-payment "Pay commission" button).
func (s *DueService) CreateSettlementOrder(ctx context.Context, techUserID, dueID string) (*DueOrder, error) {
	ids, total, err := s.repo.PendingIDsAndTotal(ctx, techUserID, dueID)
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 || total <= 0 {
		return nil, errors.New("you have no pending dues")
	}
	paise := int64(total*100 + 0.5)
	resp, err := s.client.Order.Create(map[string]interface{}{
		"amount":   paise,
		"currency": "INR",
		"receipt":  fmt.Sprintf("due_%d", time.Now().UnixNano()),
		"notes":    map[string]interface{}{"type": "technician_dues", "user_id": techUserID},
	}, nil)
	if err != nil {
		return nil, fmt.Errorf("razorpay: failed to create order: %w", err)
	}
	orderID, _ := resp["id"].(string)
	if orderID == "" {
		return nil, errors.New("razorpay: order creation did not return an order id")
	}
	if err := s.repo.CreateSettlement(ctx, techUserID, orderID, total, ids); err != nil {
		return nil, err
	}
	return &DueOrder{OrderID: orderID, KeyID: s.keyID, AmountPaise: paise, Amount: total, Currency: "INR"}, nil
}

// VerifySettlement re-derives the Razorpay signature server-side (never trusts
// the app's word) and only then clears the dues.
func (s *DueService) VerifySettlement(ctx context.Context, techUserID, orderID, paymentID, signature string) (*models.DueSummary, error) {
	if orderID == "" || paymentID == "" || signature == "" {
		return nil, errors.New("order id, payment id and signature are all required")
	}
	mac := hmac.New(sha256.New, []byte(s.keySecret))
	mac.Write([]byte(orderID + "|" + paymentID))
	if !hmac.Equal([]byte(hex.EncodeToString(mac.Sum(nil))), []byte(signature)) {
		return nil, ErrPaymentNotVerified
	}
	if err := s.repo.MarkSettlementPaid(ctx, techUserID, orderID, paymentID); err != nil {
		return nil, err
	}
	return s.Summary(ctx, techUserID)
}