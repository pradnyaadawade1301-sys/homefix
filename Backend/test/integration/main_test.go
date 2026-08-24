// Package integration_test runs real HTTP requests through the full app
// (internal/testserver — the exact same wiring as cmd/server/main.go) against a
// real Postgres. Requires TEST_DATABASE_URL; every test skips itself if it's
// unset, so `go test ./...` still passes in an environment without a test DB —
// but set it (see README) to actually run these.
package integration_test

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

var pool *pgxpool.Pool

func TestMain(m *testing.M) {
	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		// No test DB configured — every test below calls requireDB(t) and skips
		// itself, so just run (they'll all report SKIP, not FAIL).
		os.Exit(m.Run())
	}

	var err error
	pool, err = pgxpool.New(context.Background(), dbURL)
	if err != nil {
		panic(err)
	}
	defer pool.Close()

	os.Exit(m.Run())
}

// requireDB skips the test if TEST_DATABASE_URL wasn't provided.
func requireDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	if pool == nil {
		t.Skip("TEST_DATABASE_URL not set — skipping integration test")
	}
	return pool
}

// truncateAll wipes every table that a test might have written to, in FK-safe
// order, so each test starts from a clean (but still fully migrated, seeded
// categories intact) slate.
func truncateAll(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	tables := []string{
		"audit_logs", "dispute_evidence", "disputes",
		"spare_part_stock_movements", "spare_part_orders", "spare_parts", "suppliers",
		"cms_banners", "cms_announcements", "cms_faqs", "cms_pages",
		"wallet_transactions", "wallets",
		"payments", "reviews",
		"booking_messages", "booking_status_history", "bookings",
		"consultations",
		"ai_diagnosis_messages", "ai_diagnosis_sessions",
		"addresses",
		"technicians",
		"notifications",
	}
	for _, tbl := range tables {
		if _, err := pool.Exec(context.Background(), "TRUNCATE TABLE "+tbl+" CASCADE"); err != nil {
			t.Fatalf("truncate %s: %v", tbl, err)
		}
	}
	// Users: keep the seeded admin (migration 010) but remove anything a test created.
	if _, err := pool.Exec(context.Background(), "DELETE FROM users WHERE email <> 'admin@homefixlive.local'"); err != nil {
		t.Fatalf("cleanup users: %v", err)
	}
}
