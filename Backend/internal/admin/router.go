package admin

import (
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/middleware"
)

// RegisterRoutes mounts the entire hidden admin web panel at /admin. Called once
// from main.go — nothing here is nested under /api/v1, and nothing in the
// Flutter app links here (see package doc comment in admin.go).
func RegisterRoutes(r *gin.Engine, d *Deps) {
	g := r.Group("/admin")

	// Public within /admin: only the login page/submit. Login is brute-force
	// protected the same way the mobile API's own login is (see router.go).
	g.GET("/login", d.handleLoginPage)
	g.POST("/login", middleware.RateLimit(d.Cache, "admin-login", 10, time.Minute), d.handleLoginSubmit)

	// Everything else requires a valid admin session cookie.
	authed := g.Group("")
	authed.Use(d.requireAdminSession)
	{
		authed.POST("/logout", d.handleLogout)

		authed.GET("", d.handleDashboard)

		authed.GET("/users", d.handleUsersList)
		authed.POST("/users/:id/toggle-active", d.handleToggleUserActive)

		authed.GET("/technicians", d.handleTechniciansList)
		authed.POST("/technicians/:id/approve", d.handleApproveTechnician)
		authed.POST("/technicians/:id/reject", d.handleRejectTechnician)

		authed.GET("/bookings", d.handleBookingsList)

		authed.GET("/payments", d.handlePaymentsList)
		authed.POST("/payments/:id/refund", d.handleRefundPayment)

		authed.GET("/disputes", d.handleDisputesList)
		authed.POST("/disputes/:id/review", d.handleDisputeReview)
		authed.POST("/disputes/:id/resolve", d.handleDisputeResolve)

		authed.GET("/inventory", d.handleInventoryList)
		authed.POST("/inventory/parts", d.handleCreateSparePart)
		authed.POST("/inventory/parts/:id/restock", d.handleRestockPart)
		authed.POST("/inventory/suppliers", d.handleCreateSupplier)

		authed.GET("/cms", d.handleCmsList)
		authed.POST("/cms/pages/:key", d.handleSaveCmsPage)
		authed.POST("/cms/faqs", d.handleCreateFaq)
		authed.POST("/cms/faqs/:id/toggle", d.handleToggleFaq)
		authed.POST("/cms/faqs/:id/delete", d.handleDeleteFaq)
		authed.POST("/cms/announcements", d.handleCreateAnnouncement)
		authed.POST("/cms/announcements/:id/toggle", d.handleToggleAnnouncement)
		authed.POST("/cms/banners", d.handleCreateBanner)
		authed.POST("/cms/banners/:id/toggle", d.handleToggleBanner)

		authed.GET("/analytics", d.handleAnalytics)
		authed.GET("/analytics/export.csv", d.handleAnalyticsExport)

		authed.GET("/audit-logs", d.handleAuditLogs)
	}
}
