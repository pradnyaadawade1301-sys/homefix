package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	razorpay "github.com/razorpay/razorpay-go"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// RazorpayService replaces the old raw upi://pay-intent flow (see the now-unused
// UpiService, kept only for the admin panel's Refund action) with a real payment
// gateway: an order is created server-side via the Razorpay API, the app opens
// Razorpay's Checkout SDK with that order_id, and once the customer pays, the app
// hands back Checkout's own response (razorpay_payment_id + razorpay_signature) —
// which this service independently re-verifies with an HMAC-SHA256 signature
// check using the account's key secret before ever marking a payment paid. This
// is the standard, gateway-verified alternative to trusting a bare "the UPI app
// said SUCCESS" client report.
type RazorpayService struct {
	client            *razorpay.Client
	keyID             string
	keySecret         string
	commissionPct     float64
	gstPct            float64
	repeatDiscountPct float64
	paymentRepo       *repository.PaymentRepository
	bookingRepo       *repository.BookingRepository
	technicianRepo    *repository.TechnicianRepository
	walletRepo        *repository.WalletRepository
}

func NewRazorpayService(
	keyID, keySecret string,
	commissionPct float64,
	gstPct float64,
	repeatDiscountPct float64,
	paymentRepo *repository.PaymentRepository,
	bookingRepo *repository.BookingRepository,
	technicianRepo *repository.TechnicianRepository,
	walletRepo *repository.WalletRepository,
) *RazorpayService {
	return &RazorpayService{
		client:            razorpay.NewClient(keyID, keySecret),
		keyID:             keyID,
		keySecret:         keySecret,
		commissionPct:     commissionPct,
		gstPct:            gstPct,
		repeatDiscountPct: repeatDiscountPct,
		paymentRepo:       paymentRepo,
		bookingRepo:       bookingRepo,
		technicianRepo:    technicianRepo,
		walletRepo:        walletRepo,
	}
}

// RazorpayOrder is what the app needs to open Razorpay's Checkout SDK — the
// order_id ties Checkout's payment back to our own payment row, and key_id lets
// the app initialize Checkout without hardcoding it (still safe to expose
// client-side — it's the *public* key, never the secret).
type RazorpayOrder struct {
	Payment     *models.Payment `json:"payment"`
	OrderID     string          `json:"razorpay_order_id"`
	KeyID       string          `json:"razorpay_key_id"`
	AmountPaise int64           `json:"amount_paise"`
	Currency    string          `json:"currency"`
}

// CreateOrder validates the amount against the booking's invoiced final_price (if
// set), applies the repeat-customer discount + GST exactly like the old UPI flow
// did, creates a real order via the Razorpay API, and records a "created" payment
// row tagged with that order's ID.
func (s *RazorpayService) CreateOrder(ctx context.Context, bookingID, userID string, baseAmountRupees float64) (*RazorpayOrder, error) {
	booking, err := s.bookingRepo.GetByID(ctx, bookingID)
	if err != nil {
		return nil, err
	}
	if booking == nil {
		return nil, errors.New("booking not found")
	}
	if booking.FinalPrice != nil {
		const epsilon = 0.01
		diff := baseAmountRupees - *booking.FinalPrice
		if diff < -epsilon || diff > epsilon {
			return nil, fmt.Errorf("amount does not match invoiced amount of %.2f", *booking.FinalPrice)
		}
	}

	// Repeat-customer discount — identical logic to the old UPI flow.
	var isRepeat bool
	var repeatDiscountPercent *float64
	var repeatDiscountAmount *float64
	effectiveBase := baseAmountRupees
	if booking.TechnicianID != nil && s.repeatDiscountPct > 0 {
		priorCount, err := s.bookingRepo.CountPriorBookings(ctx, booking.CustomerID, *booking.TechnicianID)
		if err != nil {
			return nil, err
		}
		if priorCount > 0 {
			isRepeat = true
			pct := s.repeatDiscountPct
			amt := baseAmountRupees * pct / 100
			repeatDiscountPercent = &pct
			repeatDiscountAmount = &amt
			effectiveBase = baseAmountRupees - amt
		}
	}

	ref, err := generateTransactionRef()
	if err != nil {
		return nil, fmt.Errorf("razorpay: failed to generate transaction ref: %w", err)
	}

	gstAmount := effectiveBase * s.gstPct / 100
	totalAmount := effectiveBase + gstAmount
	amountPaise := int64(totalAmount*100 + 0.5) // Razorpay wants amount in the smallest currency unit (paise)

	orderData := map[string]interface{}{
		"amount":   amountPaise,
		"currency": "INR",
		"receipt":  ref,
		"notes": map[string]interface{}{
			"booking_id": bookingID,
			"user_id":    userID,
		},
	}
	orderResp, err := s.client.Order.Create(orderData, nil)
	if err != nil {
		return nil, fmt.Errorf("razorpay: failed to create order: %w", err)
	}
	orderID, _ := orderResp["id"].(string)
	if orderID == "" {
		return nil, errors.New("razorpay: order creation did not return an order id")
	}

	p := &models.Payment{
		BookingID:              bookingID,
		UserID:                 userID,
		TransactionRef:         ref,
		Amount:                 totalAmount,
		BaseAmount:             &effectiveBase,
		GstAmount:              &gstAmount,
		GstPercent:             &s.gstPct,
		Currency:               "INR",
		IsRepeatCustomer:       isRepeat,
		RepeatDiscountPercent:  repeatDiscountPercent,
		RepeatDiscountAmount:   repeatDiscountAmount,
		RazorpayOrderID:        &orderID,
	}
	created, err := s.paymentRepo.Create(ctx, p)
	if err != nil {
		return nil, err
	}

	return &RazorpayOrder{
		Payment:     created,
		OrderID:     orderID,
		KeyID:       s.keyID,
		AmountPaise: amountPaise,
		Currency:    "INR",
	}, nil
}

// ErrPaymentNotVerified is declared in upi_service.go (same package) and reused
// here — both flows report the same failure mode to callers.

// verifySignature re-derives Razorpay's signature exactly the way their docs
// specify: HMAC-SHA256 of "order_id|payment_id" using the account's key secret,
// hex-encoded, compared against what Checkout returned. This is the standard
// server-side check (same one Razorpay's own PHP/Node examples use directly,
// since the razorpay-go SDK doesn't expose a signature-verification helper) —
// what actually proves the payment response wasn't spoofed by a compromised or
// modified client. Never trust razorpay_payment_id alone.
func (s *RazorpayService) verifySignature(orderID, paymentID, signature string) bool {
	mac := hmac.New(sha256.New, []byte(s.keySecret))
	mac.Write([]byte(orderID + "|" + paymentID))
	expected := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(signature))
}

// VerifyAndCapture is the only place a payment (and therefore its booking) can
// become "paid". It independently re-derives and checks the Razorpay signature
// server-side (see verifySignature) rather than trusting the app's report of
// success — the same integrity guarantee a webhook would give, applied
// synchronously to the client's own callback.
func (s *RazorpayService) VerifyAndCapture(ctx context.Context, razorpayOrderID, razorpayPaymentID, razorpaySignature, method string) (*models.Payment, error) {
	if razorpayOrderID == "" || razorpayPaymentID == "" || razorpaySignature == "" {
		return nil, errors.New("razorpay: order id, payment id and signature are all required")
	}
	if !s.verifySignature(razorpayOrderID, razorpayPaymentID, razorpaySignature) {
		return nil, ErrPaymentNotVerified
	}

	p, err := s.paymentRepo.GetByRazorpayOrderID(ctx, razorpayOrderID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, fmt.Errorf("razorpay: payment not found for order %s", razorpayOrderID)
	}
	if p.Status != models.PaymentCreated {
		// Already resolved (paid/failed/refunded) — idempotent no-op, never re-credit.
		return p, nil
	}

	booking, err := s.bookingRepo.GetByID(ctx, p.BookingID)
	if err != nil {
		return nil, err
	}
	if booking == nil {
		return nil, errors.New("razorpay: booking not found for this payment")
	}

	// Commission is calculated on the base (pre-GST) amount, not the GST-inclusive
	// total — GST is the government's share, not revenue the platform or
	// technician split. p.BaseAmount is the effective base computed at
	// CreateOrder time (post repeat-customer discount); fall back to the total
	// only for legacy payments that predate the BaseAmount column.
	commissionBase := p.Amount
	if p.BaseAmount != nil {
		commissionBase = *p.BaseAmount
	}
	platformCommission := commissionBase * s.commissionPct / 100
	technicianEarning := commissionBase - platformCommission

	// CGST/SGST split — India intra-state GST is always divided 50/50 between
	// the two. p.GstAmount was already computed at CreateOrder time (post
	// repeat-customer discount, pre-total) — just split it, don't recompute.
	var cgstAmount, sgstAmount float64
	if p.GstAmount != nil {
		cgstAmount = *p.GstAmount / 2
		sgstAmount = *p.GstAmount - cgstAmount // avoids a rounding-off-by-a-paisa mismatch vs GstAmount
	}

	if method == "" {
		method = "razorpay"
	}
	invoiceNumber := fmt.Sprintf("INV-%s-%s", time.Now().Format("200601"), p.ID[:8])

	if err := s.paymentRepo.MarkVerifiedPaidRazorpay(
		ctx, razorpayOrderID, razorpayPaymentID, razorpaySignature, method, invoiceNumber,
		cgstAmount, sgstAmount, platformCommission, technicianEarning,
	); err != nil {
		return nil, err
	}
	if err := s.bookingRepo.SetPaymentStatus(ctx, booking.ID, "paid"); err != nil {
		return nil, err
	}

	// Credit the assigned technician's wallet with their net earning (amount
	// minus platform commission). If no technician is assigned yet, the payment
	// still succeeds — settlement can be reconciled manually.
	if booking.TechnicianID != nil {
		tech, err := s.technicianRepo.GetByID(ctx, *booking.TechnicianID)
		if err == nil && tech != nil {
			_, _ = s.walletRepo.Credit(ctx, tech.UserID, technicianEarning, "booking_earning", &p.ID)
		}
	}

	return s.paymentRepo.GetByRazorpayOrderID(ctx, razorpayOrderID)
}

// MarkFailed lets the app tell us Checkout was dismissed/cancelled/failed (e.g.
// the customer backed out of the payment sheet) so the payment record — and any
// retry UI — reflects that accurately.
func (s *RazorpayService) MarkFailed(ctx context.Context, razorpayOrderID string) error {
	p, err := s.paymentRepo.GetByRazorpayOrderID(ctx, razorpayOrderID)
	if err != nil {
		return err
	}
	if p == nil {
		return fmt.Errorf("razorpay: payment not found for order %s", razorpayOrderID)
	}
	return s.paymentRepo.MarkFailed(ctx, p.TransactionRef, strings.ToUpper("failed"), "")
}

func (s *RazorpayService) GetByID(ctx context.Context, id string) (*models.Payment, error) {
	return s.paymentRepo.GetByID(ctx, id)
}

func (s *RazorpayService) ListByUser(ctx context.Context, userID string) ([]models.Payment, error) {
	return s.paymentRepo.ListByUser(ctx, userID)
}

// GetInvoice returns the full invoice for a payment — only once it's actually
// paid (a 'created' or 'failed' payment has no real invoice, just a would-be
// one, which would be misleading to hand back as if it were final).
func (s *RazorpayService) GetInvoice(ctx context.Context, paymentID, requestingUserID string) (*models.InvoiceDetail, error) {
	p, err := s.paymentRepo.GetByID(ctx, paymentID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, errors.New("payment not found")
	}
	if p.UserID != requestingUserID {
		return nil, errors.New("you are not authorized to view this invoice")
	}
	if p.Status != models.PaymentPaid && p.Status != models.PaymentRefunded {
		return nil, errors.New("invoice is only available once payment is complete")
	}
	inv, err := s.paymentRepo.GetInvoiceDetail(ctx, paymentID)
	if err != nil {
		return nil, err
	}
	if inv == nil {
		return nil, errors.New("invoice not found")
	}
	return inv, nil
}

// Refund reverses a verified payment: the booking's payment_status moves to
// "refunded", the technician's earning credit is clawed back, and the customer is
// credited the full amount to their in-app wallet. If the payment actually went
// through Razorpay (razorpay_payment_id set), a real refund is also issued via the
// Razorpay API so the money genuinely goes back to the customer's original payment
// method — not just an in-app credit. Falls back to wallet-only reversal (same as
// the old UPI flow) for any legacy payment that predates Razorpay.
func (s *RazorpayService) Refund(ctx context.Context, paymentID string) (*models.Payment, error) {
	p, err := s.paymentRepo.GetByID(ctx, paymentID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, errors.New("payment not found")
	}
	if p.Status != models.PaymentPaid {
		return nil, errors.New("only a paid payment can be refunded")
	}

	if p.RazorpayPaymentID != nil && *p.RazorpayPaymentID != "" {
		amountPaise := int(p.Amount*100 + 0.5)
		if _, err := s.client.Payment.Refund(*p.RazorpayPaymentID, amountPaise, nil, nil); err != nil {
			// The gateway call actually failed — real money has NOT gone back to
			// the customer. Stop here instead of marking "refunded" and crediting
			// the wallet, which would let a customer believe (and use) money that
			// was never actually returned. Caller/admin should retry the refund.
			return nil, fmt.Errorf("razorpay: gateway refund failed, payment not marked refunded: %w", err)
		}
	}

	if err := s.paymentRepo.Refund(ctx, paymentID, time.Now()); err != nil {
		return nil, err
	}
	if err := s.bookingRepo.SetPaymentStatus(ctx, p.BookingID, "refunded"); err != nil {
		return nil, err
	}

	if p.TechnicianEarning != nil {
		booking, err := s.bookingRepo.GetByID(ctx, p.BookingID)
		if err == nil && booking != nil && booking.TechnicianID != nil {
			tech, err := s.technicianRepo.GetByID(ctx, *booking.TechnicianID)
			if err == nil && tech != nil {
				_, _ = s.walletRepo.Debit(ctx, tech.UserID, *p.TechnicianEarning, "booking_refund_clawback", &p.ID)
			}
		}
	}
	_, _ = s.walletRepo.Credit(ctx, p.UserID, p.Amount, "booking_refund", &p.ID)

	return s.paymentRepo.GetByID(ctx, paymentID)
}