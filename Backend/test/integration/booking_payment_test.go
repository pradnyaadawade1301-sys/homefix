package integration_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"homefix-backend/internal/testserver"
)

// fixture is everything a booking+payment test needs: a signed-up, approved
// technician and a signed-up customer with a saved address, plus a category id
// from the seeded categories (migrations 002/004).
type fixture struct {
	customerToken string
	techToken     string
	techID        string
	techUserID    string
	categoryID    string
	addressID     string
}

func setUpBookingFixture(t *testing.T, srv *testserver.Server) fixture {
	t.Helper()
	ctx := context.Background()

	// Category — use whatever the seed migrations already inserted.
	cats, err := srv.CatRepo.List(ctx)
	require.NoError(t, err)
	require.NotEmpty(t, cats, "categories must be seeded (migrations 002/004)")
	categoryID := cats[0].ID

	// Technician signup + KYC + admin-approve (bypassing the HTTP admin panel here —
	// that flow itself is covered by admin_test.go).
	techSignup := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name": "Test Technician", "email": "tech1@example.com", "phone": "9100000001",
		"password": "password123", "role": "technician",
	}, "")
	require.Equal(t, http.StatusCreated, techSignup.Code, techSignup.Body.String())
	techData := decodeEnvelope(t, techSignup)["data"].(map[string]interface{})
	techToken := techData["access_token"].(string)
	techUserID := techData["user"].(map[string]interface{})["id"].(string)

	regRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/technicians", map[string]interface{}{
		"category_id":       categoryID,
		"experience_years":  3,
		"address":           "123 Test Street",
		"government_id_url": "http://example.com/id.jpg",
		"profile_photo_url": "http://example.com/photo.jpg",
	}, techToken)
	require.Equal(t, http.StatusCreated, regRec.Code, regRec.Body.String())
	techID := decodeEnvelope(t, regRec)["data"].(map[string]interface{})["id"].(string)

	require.NoError(t, srv.TechRepo.SetApprovalStatus(ctx, techID, "approved", ""))

	// Customer signup + saved address.
	custSignup := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name": "Test Customer", "email": "paycust1@example.com", "phone": "9100000002",
		"password": "password123", "role": "customer",
	}, "")
	require.Equal(t, http.StatusCreated, custSignup.Code, custSignup.Body.String())
	custData := decodeEnvelope(t, custSignup)["data"].(map[string]interface{})
	customerToken := custData["access_token"].(string)

	addrRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/users/me/addresses", map[string]interface{}{
		"label": "Home", "line1": "456 Customer Ave", "city": "Testville", "state": "TS", "pincode": "123456",
	}, customerToken)
	require.Equal(t, http.StatusCreated, addrRec.Code, addrRec.Body.String())
	addressID := decodeEnvelope(t, addrRec)["data"].(map[string]interface{})["id"].(string)

	return fixture{
		customerToken: customerToken,
		techToken:     techToken,
		techID:        techID,
		techUserID:    techUserID,
		categoryID:    categoryID,
		addressID:     addressID,
	}
}

// TestPaymentConfirm_RejectsUnverifiedStatus is the single most important test in
// this project: it proves a booking cannot become "paid" from a bare client claim
// — only a UPI app's own reported SUCCESS status can do that (see
// UpiService.ConfirmPayment).
func TestPaymentConfirm_RejectsUnverifiedStatus(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)
	fx := setUpBookingFixture(t, srv)
	ctx := context.Background()

	bookingRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/bookings", map[string]interface{}{
		"category_id": fx.categoryID, "address_id": fx.addressID, "problem_description": "Leaky tap",
	}, fx.customerToken)
	require.Equal(t, http.StatusCreated, bookingRec.Code, bookingRec.Body.String())
	bookingID := decodeEnvelope(t, bookingRec)["data"].(map[string]interface{})["id"].(string)

	acceptRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/bookings/"+bookingID+"/accept",
		map[string]string{"technician_id": fx.techID}, fx.techToken)
	require.Equal(t, http.StatusOK, acceptRec.Code, acceptRec.Body.String())

	orderRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/orders",
		map[string]interface{}{"booking_id": bookingID, "amount": 500.0}, fx.customerToken)
	require.Equal(t, http.StatusCreated, orderRec.Code, orderRec.Body.String())
	txnRef := decodeEnvelope(t, orderRec)["data"].(map[string]interface{})["transaction_ref"].(string)

	// The client claims success with no real UPI status — must be rejected.
	badConfirm := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/confirm", map[string]interface{}{
		"transaction_ref": txnRef, "upi_status": "submitted",
	}, fx.customerToken)
	assert.Equal(t, http.StatusUnprocessableEntity, badConfirm.Code, badConfirm.Body.String())

	// Booking must still show payment pending.
	b, err := srv.BookingRepo.GetByID(ctx, bookingID)
	require.NoError(t, err)
	assert.Equal(t, "pending", b.PaymentStatus)

	// A FAILURE report must also never mark it paid.
	failConfirm := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/confirm", map[string]interface{}{
		"transaction_ref": txnRef, "upi_status": "failure",
	}, fx.customerToken)
	assert.Equal(t, http.StatusUnprocessableEntity, failConfirm.Code)

	b, err = srv.BookingRepo.GetByID(ctx, bookingID)
	require.NoError(t, err)
	assert.Equal(t, "pending", b.PaymentStatus)
}

// TestPaymentConfirm_VerifiedSuccessPaysBookingAndCreditsTechnician exercises the
// full happy path: a real SUCCESS response from the UPI app marks the payment (and
// booking) paid, and splits the amount into platform commission + technician
// wallet credit.
func TestPaymentConfirm_VerifiedSuccessPaysBookingAndCreditsTechnician(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)
	fx := setUpBookingFixture(t, srv)
	ctx := context.Background()

	bookingRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/bookings", map[string]interface{}{
		"category_id": fx.categoryID, "address_id": fx.addressID, "problem_description": "Fan not working",
	}, fx.customerToken)
	require.Equal(t, http.StatusCreated, bookingRec.Code, bookingRec.Body.String())
	bookingID := decodeEnvelope(t, bookingRec)["data"].(map[string]interface{})["id"].(string)

	acceptRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/bookings/"+bookingID+"/accept",
		map[string]string{"technician_id": fx.techID}, fx.techToken)
	require.Equal(t, http.StatusOK, acceptRec.Code, acceptRec.Body.String())

	orderRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/orders",
		map[string]interface{}{"booking_id": bookingID, "amount": 1000.0}, fx.customerToken)
	require.Equal(t, http.StatusCreated, orderRec.Code, orderRec.Body.String())
	txnRef := decodeEnvelope(t, orderRec)["data"].(map[string]interface{})["transaction_ref"].(string)

	confirmRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/confirm", map[string]interface{}{
		"transaction_ref": txnRef, "upi_txn_id": "UPI123456789", "upi_status": "SUCCESS",
		"upi_response_code": "00",
	}, fx.customerToken)
	require.Equal(t, http.StatusOK, confirmRec.Code, confirmRec.Body.String())
	payment := decodeEnvelope(t, confirmRec)["data"].(map[string]interface{})
	assert.Equal(t, "paid", payment["status"])
	assert.Equal(t, true, payment["verified"])

	b, err := srv.BookingRepo.GetByID(ctx, bookingID)
	require.NoError(t, err)
	assert.Equal(t, "paid", b.PaymentStatus)

	// 15% default commission on 1000 -> technician nets 850.
	wallet, err := srv.WalletRepo.GetOrCreate(ctx, fx.techUserID)
	require.NoError(t, err)
	assert.Equal(t, 850.0, wallet.Balance)

	// Re-confirming the same transaction ref must be a no-op, never double-credit.
	confirmAgain := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/confirm", map[string]interface{}{
		"transaction_ref": txnRef, "upi_txn_id": "UPI123456789", "upi_status": "SUCCESS",
	}, fx.customerToken)
	require.Equal(t, http.StatusOK, confirmAgain.Code)

	wallet, err = srv.WalletRepo.GetOrCreate(ctx, fx.techUserID)
	require.NoError(t, err)
	assert.Equal(t, 850.0, wallet.Balance, "confirming an already-paid transaction must not credit the wallet twice")
}
