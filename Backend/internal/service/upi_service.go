package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// UpiService replaces the old Razorpay integration with a direct UPI intent flow —
// no payment-gateway account/keys needed. The backend hands the app a `upi://pay`
// deep link (works with GPay, PhonePe, Paytm — Android resolves it to whichever
// UPI apps are installed); the customer pays there and the app captures the UPI
// app's OWN response (via startActivityForResult, not a plain "I paid" button —
// see ConfirmPayment) and reports it back here.
type UpiService struct {
	payeeVPA       string
	payeeName      string
	commissionPct  float64
	paymentRepo    *repository.PaymentRepository
	bookingRepo    *repository.BookingRepository
	technicianRepo *repository.TechnicianRepository
	walletRepo     *repository.WalletRepository
}

func NewUpiService(
	payeeVPA, payeeName string,
	commissionPct float64,
	paymentRepo *repository.PaymentRepository,
	bookingRepo *repository.BookingRepository,
	technicianRepo *repository.TechnicianRepository,
	walletRepo *repository.WalletRepository,
) *UpiService {
	return &UpiService{
		payeeVPA:       payeeVPA,
		payeeName:      payeeName,
		commissionPct:  commissionPct,
		paymentRepo:    paymentRepo,
		bookingRepo:    bookingRepo,
		technicianRepo: technicianRepo,
		walletRepo:     walletRepo,
	}
}

// UpiOrder is what the app needs to launch the payment and show the user what
// they're paying for. PayeeVPA/PayeeName are always HomeFix's own configured
// payee — the app must not let the customer redirect payment to an arbitrary UPI
// ID, since ConfirmPayment has no way to verify money reached anyone but our own
// account.
type UpiOrder struct {
	Payment        *models.Payment `json:"payment"`
	UpiURI         string          `json:"upi_uri"`
	PayeeVPA       string          `json:"payee_vpa"`
	PayeeName      string          `json:"payee_name"`
	TransactionRef string          `json:"transaction_ref"`
}

func generateTransactionRef() (string, error) {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return fmt.Sprintf("HF%d%s", time.Now().Unix(), hex.EncodeToString(b)), nil
}

// CreateOrder records a "created" payment and builds its UPI deep link.
func (s *UpiService) CreateOrder(ctx context.Context, bookingID, userID string, amountRupees float64) (*UpiOrder, error) {
	ref, err := generateTransactionRef()
	if err != nil {
		return nil, fmt.Errorf("upi: failed to generate transaction ref: %w", err)
	}

	p := &models.Payment{
		BookingID:      bookingID,
		UserID:         userID,
		TransactionRef: ref,
		Amount:         amountRupees,
		Currency:       "INR",
	}
	created, err := s.paymentRepo.Create(ctx, p)
	if err != nil {
		return nil, err
	}

	note := "HomeFix Live booking " + bookingID
	uri := fmt.Sprintf("upi://pay?pa=%s&pn=%s&tr=%s&am=%s&cu=INR&tn=%s",
		url.QueryEscape(s.payeeVPA),
		url.QueryEscape(s.payeeName),
		url.QueryEscape(ref),
		fmt.Sprintf("%.2f", amountRupees),
		url.QueryEscape(note),
	)

	return &UpiOrder{
		Payment:        created,
		UpiURI:         uri,
		PayeeVPA:       s.payeeVPA,
		PayeeName:      s.payeeName,
		TransactionRef: ref,
	}, nil
}

// ErrPaymentNotVerified means the UPI app's own response wasn't a clear success —
// the caller should NOT treat the booking as paid and should let the customer retry.
var ErrPaymentNotVerified = errors.New("payment could not be verified as successful")

// ConfirmPayment is the only place a payment (and therefore its booking) can become
// "paid". There's no server-to-server gateway callback for a raw UPI intent — the
// most a non-PSP integration can honestly verify is the UPI app's OWN response to
// the app that launched it (returned via startActivityForResult: status/txnId/
// responseCode/approvalRefNo — see the app's PaymentService.confirm, which now
// requires these instead of a bare "user says they paid" flag). Only upiStatus ==
// "SUCCESS" (case-insensitive, as UPI apps report it) is accepted; anything else
// leaves the payment exactly as it was so the app can retry rather than silently
// crediting a technician for money that was never actually verified as received.
func (s *UpiService) ConfirmPayment(
	ctx context.Context,
	transactionRef, upiTxnID, method, upiStatus, upiResponseCode, upiApprovalRef string,
) (*models.Payment, error) {
	p, err := s.paymentRepo.GetByTransactionRef(ctx, transactionRef)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, fmt.Errorf("upi: payment not found for transaction ref %s", transactionRef)
	}
	if p.Status != models.PaymentCreated {
		// Already resolved (paid/failed/refunded) — idempotent no-op, never re-credit.
		return p, nil
	}

	if !strings.EqualFold(upiStatus, "SUCCESS") {
		if strings.EqualFold(upiStatus, "FAILURE") {
			_ = s.paymentRepo.MarkFailed(ctx, transactionRef, upiStatus, upiResponseCode)
		}
		return nil, ErrPaymentNotVerified
	}
	if upiTxnID == "" {
		return nil, errors.New("upi: SUCCESS response missing a transaction id — cannot verify")
	}

	booking, err := s.bookingRepo.GetByID(ctx, p.BookingID)
	if err != nil {
		return nil, err
	}
	if booking == nil {
		return nil, errors.New("upi: booking not found for this payment")
	}

	platformCommission := p.Amount * s.commissionPct / 100
	technicianEarning := p.Amount - platformCommission

	if method == "" {
		method = "upi"
	}
	invoiceNumber := fmt.Sprintf("INV-%s-%s", time.Now().Format("200601"), p.ID[:8])

	if err := s.paymentRepo.MarkVerifiedPaid(
		ctx, transactionRef, upiTxnID, method, invoiceNumber, strings.ToUpper(upiStatus), upiResponseCode, upiApprovalRef,
		platformCommission, technicianEarning,
	); err != nil {
		return nil, err
	}
	if err := s.bookingRepo.SetPaymentStatus(ctx, booking.ID, "paid"); err != nil {
		return nil, err
	}

	// Credit the assigned technician's wallet with their net earning (amount minus
	// platform commission). If no technician is assigned yet (shouldn't normally
	// happen for a payable booking), the payment still succeeds — settlement can be
	// reconciled manually — rather than failing an otherwise-verified payment.
	if booking.TechnicianID != nil {
		tech, err := s.technicianRepo.GetByID(ctx, *booking.TechnicianID)
		if err == nil && tech != nil {
			_, _ = s.walletRepo.Credit(ctx, tech.UserID, technicianEarning, "booking_earning", &p.ID)
		}
	}

	return s.paymentRepo.GetByTransactionRef(ctx, transactionRef)
}

func (s *UpiService) MarkFailed(ctx context.Context, transactionRef string) error {
	return s.paymentRepo.MarkFailed(ctx, transactionRef, "", "")
}

func (s *UpiService) GetByID(ctx context.Context, id string) (*models.Payment, error) {
	return s.paymentRepo.GetByID(ctx, id)
}

func (s *UpiService) ListByUser(ctx context.Context, userID string) ([]models.Payment, error) {
	return s.paymentRepo.ListByUser(ctx, userID)
}

// Refund reverses a verified payment: the booking's payment_status moves to
// "refunded", the technician's earning credit is clawed back, and the customer is
// credited the full amount to their in-app wallet (there's no gateway to push money
// back to their UPI account directly without a PSP, so an in-app wallet credit —
// redeemable against a future booking, or manually settled by an admin — is the
// honest equivalent here).
func (s *UpiService) Refund(ctx context.Context, paymentID string) (*models.Payment, error) {
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
