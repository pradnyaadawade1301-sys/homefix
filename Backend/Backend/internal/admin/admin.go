// Package admin implements the hidden, server-rendered web panel for HomeFix
// Live. It is mounted at /admin by router.Setup and is NEVER reachable from, or
// linked to, the Flutter app — there is no "Admin" button anywhere in the mobile
// UI and none of these routes live under /api/v1. Access is gated by its own
// session cookie (see session.go), issued only to users with role == "admin",
// which the public signup flow (auth_handler.go) can never create.
package admin

import (
	"homefix-backend/internal/cache"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/service"
)

// Deps is every service the admin panel's handlers need. Handed in from main.go
// so the panel reuses the exact same business logic (and therefore the exact same
// invariants — verified payments, commission math, KYC rules) as the mobile API.
type Deps struct {
	Admin     *service.AdminService
	Dispute   *service.DisputeService
	Inventory *service.InventoryService
	Cms       *service.CmsService
	Analytics *service.AnalyticsService
	Upi       *service.UpiService
	Category  *repository.CategoryRepository
	Audit     *repository.AuditRepository
	JWTSecret string
	Cache     *cache.Client
}
