package integration_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"homefix-backend/internal/testserver"
)

func doJSON(t *testing.T, engine http.Handler, method, path string, body interface{}, token string) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		require.NoError(t, json.NewEncoder(&buf).Encode(body))
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	engine.ServeHTTP(rec, req)
	return rec
}

func decodeEnvelope(t *testing.T, rec *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var body map[string]interface{}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	return body
}

func TestSignup_CreatesCustomerAndReturnsTokens(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	rec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name":     "Test Customer",
		"email":    "customer1@example.com",
		"phone":    "9000000001",
		"password": "password123",
		"role":     "customer",
	}, "")

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	body := decodeEnvelope(t, rec)
	data := body["data"].(map[string]interface{})
	assert.NotEmpty(t, data["access_token"])
	assert.NotEmpty(t, data["refresh_token"])
	user := data["user"].(map[string]interface{})
	assert.Equal(t, "customer", user["role"])
}

func TestSignup_RejectsDuplicatePhone(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	payload := map[string]string{
		"name": "Dup User", "email": "dup1@example.com", "phone": "9000000002",
		"password": "password123", "role": "customer",
	}
	rec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", payload, "")
	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())

	payload["email"] = "dup2@example.com" // different email, same phone
	rec = doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", payload, "")
	assert.Equal(t, http.StatusBadRequest, rec.Code, "signing up twice with the same phone must fail")
}

func TestLogin_WrongPasswordRejected(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name": "Login Test", "email": "login1@example.com", "phone": "9000000003",
		"password": "correct-password", "role": "customer",
	}, "")

	rec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/login", map[string]string{
		"identifier": "login1@example.com", "password": "wrong-password",
	}, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestLogin_CorrectPasswordSucceeds(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name": "Login Test 2", "email": "login2@example.com", "phone": "9000000004",
		"password": "correct-password", "role": "customer",
	}, "")

	rec := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/login", map[string]string{
		"identifier": "login2@example.com", "password": "correct-password",
	}, "")
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
}

func TestAuthedRoute_RejectsMissingToken(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	rec := doJSON(t, srv.Engine, http.MethodGet, "/api/v1/users/me", nil, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestAuthedRoute_AcceptsValidToken(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	signup := doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name": "Me Test", "email": "me1@example.com", "phone": "9000000005",
		"password": "password123", "role": "customer",
	}, "")
	require.Equal(t, http.StatusCreated, signup.Code)
	token := decodeEnvelope(t, signup)["data"].(map[string]interface{})["access_token"].(string)

	rec := doJSON(t, srv.Engine, http.MethodGet, "/api/v1/users/me", nil, token)
	assert.Equal(t, http.StatusOK, rec.Code)
}