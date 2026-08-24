package integration_test

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"homefix-backend/internal/testserver"
)

func urlValues(identifier, password string) url.Values {
	return url.Values{"identifier": {identifier}, "password": {password}}
}

func urlValuesResolve(status, notes string) url.Values {
	return url.Values{"status": {status}, "admin_notes": {notes}}
}

func urlValuesContent(content string) url.Values {
	return url.Values{"content": {content}}
}

func postForm(engine http.Handler, path string, form url.Values, cookies []*http.Cookie) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	for _, c := range cookies {
		req.AddCookie(c)
	}
	rec := httptest.NewRecorder()
	engine.ServeHTTP(rec, req)
	return rec
}

func getWithCookies(engine http.Handler, path string, cookies []*http.Cookie) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	for _, c := range cookies {
		req.AddCookie(c)
	}
	rec := httptest.NewRecorder()
	engine.ServeHTTP(rec, req)
	return rec
}

// TestAdminPanel_HiddenFromUnauthenticated proves /admin is not casually
// reachable: no session cookie means an immediate redirect to the login page,
// never the dashboard content.
func TestAdminPanel_HiddenFromUnauthenticated(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	rec := getWithCookies(srv.Engine, "/admin", nil)
	assert.Equal(t, http.StatusFound, rec.Code, "an unauthenticated request must be redirected, not shown the dashboard")
	assert.Equal(t, "/admin/login", rec.Header().Get("Location"))
}

// TestAdminPanel_LoginRequiresAdminRole proves a normal customer account — even
// with a correct password — cannot obtain an admin session.
func TestAdminPanel_LoginRequiresAdminRole(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	doJSON(t, srv.Engine, http.MethodPost, "/api/v1/auth/signup", map[string]string{
		"name": "Plain Customer", "email": "plaincust@example.com", "phone": "9200000001",
		"password": "password123", "role": "customer",
	}, "")

	rec := postForm(srv.Engine, "/admin/login", url.Values{
		"identifier": {"plaincust@example.com"}, "password": {"password123"},
	}, nil)
	assert.Equal(t, http.StatusOK, rec.Code) // re-renders login page with an error, not a redirect
	// Deliberately generic message — must not reveal to an attacker whether the
	// failure was "wrong password" vs "right password, wrong role".
	assert.Contains(t, rec.Body.String(), "Invalid credentials or insufficient access")
	assert.Empty(t, rec.Result().Cookies(), "a non-admin login must never receive a session cookie")
}

// TestAdminPanel_SeededAdminCanLoginAndReachDashboard exercises the real seeded
// admin account (migration 010_seed_admin.sql) end-to-end: login -> cookie ->
// dashboard.
func TestAdminPanel_SeededAdminCanLoginAndReachDashboard(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool) // truncateAll deliberately keeps the seeded admin user
	srv := testserver.New(pool)

	loginRec := postForm(srv.Engine, "/admin/login", url.Values{
		"identifier": {"admin@homefixlive.local"}, "password": {"ChangeMe123!"},
	}, nil)
	require.Equal(t, http.StatusFound, loginRec.Code, loginRec.Body.String())
	require.Equal(t, "/admin", loginRec.Header().Get("Location"))

	cookies := loginRec.Result().Cookies()
	require.NotEmpty(t, cookies, "a successful admin login must set a session cookie")

	dashRec := getWithCookies(srv.Engine, "/admin", cookies)
	assert.Equal(t, http.StatusOK, dashRec.Code)
	assert.Contains(t, dashRec.Body.String(), "Total Customers")

	// And the technician approval queue, dispute queue, inventory, CMS pages are
	// all reachable with the same session (RBAC gate is role-based, not per-page).
	for _, path := range []string{"/admin/technicians", "/admin/disputes", "/admin/inventory", "/admin/cms", "/admin/analytics", "/admin/audit-logs"} {
		rec := getWithCookies(srv.Engine, path, cookies)
		assert.Equal(t, http.StatusOK, rec.Code, "GET %s should succeed with a valid admin session", path)
	}
}

// TestAdminPanel_ForgedCookieRejected proves a tampered/invalid cookie value is
// rejected the same way a missing one is (signature check, not just presence check).
func TestAdminPanel_ForgedCookieRejected(t *testing.T) {
	pool := requireDB(t)
	truncateAll(t, pool)
	srv := testserver.New(pool)

	forged := []*http.Cookie{{Name: "hf_admin_session", Value: "not-a-real-jwt"}}
	rec := getWithCookies(srv.Engine, "/admin", forged)
	assert.Equal(t, http.StatusFound, rec.Code)
	assert.Equal(t, "/admin/login", rec.Header().Get("Location"))
}
