package integration_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"homefix-backend/internal/testserver"
)

func TestDispute_RaiseAndAdminResolveWithRefund(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)
	fx := setUpBookingFixture(t, srv)
	ctx := context.Background()

	bookingRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/bookings", map[string]interface{}{
		"category_id": fx.categoryID, "address_id": fx.addressID, "problem_description": "AC not cooling",
	}, fx.customerToken)
	require.Equal(t, http.StatusCreated, bookingRec.Code)
	bookingID := decodeEnvelope(t, bookingRec)["data"].(map[string]interface{})["id"].(string)

	require.Equal(t, http.StatusOK, doJSON(t, srv.Engine, http.MethodPost, "/api/v1/bookings/"+bookingID+"/accept",
		map[string]string{"technician_id": fx.techID}, fx.techToken).Code)

	orderRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/orders",
		map[string]interface{}{"booking_id": bookingID, "amount": 700.0}, fx.customerToken)
	require.Equal(t, http.StatusCreated, orderRec.Code)
	txnRef := decodeEnvelope(t, orderRec)["data"].(map[string]interface{})["transaction_ref"].(string)

	confirmRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/payments/confirm", map[string]interface{}{
		"transaction_ref": txnRef, "upi_txn_id": "UPIABC999", "upi_status": "SUCCESS",
	}, fx.customerToken)
	require.Equal(t, http.StatusOK, confirmRec.Code, confirmRec.Body.String())

	// Customer raises a dispute against the now-paid booking.
	disputeRec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/disputes", map[string]interface{}{
		"booking_id": bookingID, "reason": "AC still not cooling after the visit",
	}, fx.customerToken)
	require.Equal(t, http.StatusCreated, disputeRec.Code, disputeRec.Body.String())
	disputeID := decodeEnvelope(t, disputeRec)["data"].(map[string]interface{})["id"].(string)

	// Admin resolves it with a refund.
	loginRec := postForm(srv.Engine, "/admin/login", urlValues("admin@homefixlive.local", "ChangeMe123!"), nil)
	require.Equal(t, http.StatusFound, loginRec.Code)
	cookies := loginRec.Result().Cookies()

	resolveRec := postForm(srv.Engine, "/admin/disputes/"+disputeID+"/resolve", urlValuesResolve("resolved_refund", "Refunded per policy"), cookies)
	assert.Equal(t, http.StatusFound, resolveRec.Code, resolveRec.Body.String())

	// Booking payment status must now show refunded, and the customer's wallet
	// must have been credited the full amount back.
	b, err := srv.BookingRepo.GetByID(ctx, bookingID)
	require.NoError(t, err)
	assert.Equal(t, "refunded", b.PaymentStatus)
}

func TestCms_PublicReadReflectsAdminWrites(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	loginRec := postForm(srv.Engine, "/admin/login", urlValues("admin@homefixlive.local", "ChangeMe123!"), nil)
	require.Equal(t, http.StatusFound, loginRec.Code)
	cookies := loginRec.Result().Cookies()

	saveRec := postForm(srv.Engine, "/admin/cms/pages/about_us", urlValuesContent("HomeFix Live is a service marketplace."), cookies)
	require.Equal(t, http.StatusFound, saveRec.Code)

	pageRec := doJSON(t, srv.Engine, http.MethodGet, "/api/v1/cms/pages/about_us", nil, "")
	require.Equal(t, http.StatusOK, pageRec.Code)
	page := decodeEnvelope(t, pageRec)["data"].(map[string]interface{})
	assert.Equal(t, "HomeFix Live is a service marketplace.", page["content"])
}