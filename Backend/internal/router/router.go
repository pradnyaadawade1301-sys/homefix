package router

import (
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/cache"
	"homefix-backend/internal/handler"
	"homefix-backend/internal/middleware"
)

type Handlers struct {
	Auth         *handler.AuthHandler
	User         *handler.UserHandler
	Category     *handler.CategoryHandler
	Technician   *handler.TechnicianHandler
	Booking      *handler.BookingHandler
	Payment      *handler.PaymentHandler
	Wallet       *handler.WalletHandler
	Review       *handler.ReviewHandler
	AI           *handler.AIHandler
	Notification *handler.NotificationHandler
	Upload       *handler.UploadHandler
	Call         *handler.CallHandler
	Consultation *handler.ConsultationHandler
	WebRTC       *handler.WebRTCHandler
	Dispute      *handler.DisputeHandler
	Cms          *handler.CmsHandler
}

func Setup(h *Handlers, accessSecret, uploadDir string, rdb *cache.Client) *gin.Engine {
	r := gin.Default()
	r.Use(corsMiddleware())
	r.Use(secureHeaders())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "homefix-backend"})
	})

	// Serves files saved by UploadHandler (technician government ID / profile photo,
	// review images, etc.) — swap for a real S3/CDN URL when AWS storage is configured.
	r.Static("/uploads", uploadDir)

	api := r.Group("/api/v1")

	// ---- Public ----
	// Brute-force protection: these are the only unauthenticated endpoints that let
	// someone guess a secret (password, OTP) or spam account creation, so they're
	// rate-limited per IP (Redis-backed — see internal/middleware/ratelimit.go).
	auth := api.Group("/auth")
	{
		auth.POST("/request-otp", middleware.RateLimit(rdb, "otp", 5, time.Minute), h.Auth.RequestOTP)
		auth.POST("/verify-otp", middleware.RateLimit(rdb, "otp-verify", 10, time.Minute), h.Auth.VerifyOTP)
		auth.POST("/signup", middleware.RateLimit(rdb, "signup", 10, time.Minute), h.Auth.Signup)
		auth.POST("/login", middleware.RateLimit(rdb, "login", 10, time.Minute), h.Auth.Login)
		auth.POST("/request-email-otp", middleware.RateLimit(rdb, "email-otp", 5, time.Minute), h.Auth.RequestEmailOTP)
		auth.POST("/verify-email-otp", middleware.RateLimit(rdb, "email-otp-verify", 10, time.Minute), h.Auth.VerifyEmailOTP)
		auth.POST("/refresh", h.Auth.Refresh)
	}
	api.GET("/categories", h.Category.List)
	api.GET("/technicians", h.Technician.List)
	api.GET("/technicians/:id", h.Technician.GetByID)

	// CMS — public, read-only. Content is authored/edited only from the hidden
	// /admin panel (see internal/admin/cms.go).
	api.GET("/cms/pages/:key", h.Cms.GetPage)
	api.GET("/cms/faqs", h.Cms.ListFaqs)
	api.GET("/cms/announcements", h.Cms.ListAnnouncements)
	api.GET("/cms/banners", h.Cms.ListBanners)

	// Video call signaling (peer-to-peer WebRTC handshake only — see CallHandler
	// doc comment). Auth is via ?token= query param, not the Authorization header,
	// because WebSocket upgrade requests can't reliably carry custom headers on
	// every platform (in particular Flutter Web) — so this sits outside the
	// header-based `authed` group and validates the JWT itself.
	api.GET("/ws/call/:id", h.Call.Signal)

	// ---- Authenticated ----
	authed := api.Group("")
	authed.Use(middleware.JWTAuth(accessSecret))
	{
		authed.POST("/auth/set-password", h.Auth.SetPassword)
		authed.POST("/auth/logout", h.Auth.Logout)

		authed.POST("/uploads", h.Upload.Upload)

		authed.GET("/users/me", h.User.GetProfile)
		authed.PUT("/users/me", h.User.UpdateProfile)
		authed.PUT("/users/me/photo", h.User.UpdatePhoto)
		authed.POST("/users/me/fcm-token", h.User.RegisterFCMToken)
		authed.POST("/users/me/addresses", h.User.AddAddress)
		authed.GET("/users/me/addresses", h.User.ListAddresses)

		authed.POST("/categories", middleware.RequireRole("admin"), h.Category.Create)

		authed.POST("/technicians", h.Technician.Register)
		authed.GET("/technicians/me", h.Technician.Me)
		authed.GET("/technicians/available", h.Technician.FindAvailable)
		authed.GET("/technicians/:id/reviews", h.Technician.Reviews)
		authed.PATCH("/technicians/:id/availability", middleware.RequireRole("technician"), h.Technician.SetAvailability)
		authed.PATCH("/technicians/:id/location", middleware.RequireRole("technician"), h.Technician.UpdateLocation)
		authed.PATCH("/technicians/:id/verify", middleware.RequireRole("admin"), h.Technician.Verify)
		authed.GET("/technicians/:id/bookings", middleware.RequireRole("technician", "admin"), h.Booking.TechnicianBookings)
		authed.GET("/technicians/:id/repeat-customers", middleware.RequireRole("technician", "admin"), h.Booking.RepeatCustomers)
		authed.GET("/technicians/:id/customers/:customerId/history", middleware.RequireRole("technician", "admin"), h.Booking.ServiceHistory)

		authed.POST("/bookings", h.Booking.Create)
		authed.GET("/bookings/me", h.Booking.MyBookings)
		authed.GET("/bookings/:id", h.Booking.Get)
		authed.GET("/bookings/:id/history", h.Booking.History)
		authed.POST("/bookings/:id/accept", middleware.RequireRole("technician"), h.Booking.Accept)
		authed.PATCH("/bookings/:id/status", middleware.RequireRole("technician", "admin"), h.Booking.UpdateStatus)
		authed.POST("/bookings/:id/complete", middleware.RequireRole("technician", "admin"), h.Booking.Complete)
		authed.POST("/bookings/:id/cancel", h.Booking.Cancel)
        authed.POST("/bookings/:id/messages", h.Booking.SendMessage)
        authed.GET("/bookings/:id/messages", h.Booking.ListMessages)
		// Live Video Consultation (on-demand, peer-to-peer) — see consultation_service.go
		// for the matching flow. The actual call media reuses the same /ws/call/:id
		// signaling relay as booking calls (CallHandler.Signal accepts either a booking
		// or a consultation id — see call_handler.go).
		authed.POST("/consultations/request", h.Consultation.Request)
		authed.GET("/consultations/pending", middleware.RequireRole("technician"), h.Consultation.Pending)
		authed.GET("/consultations/:id", h.Consultation.Get)
		authed.GET("/consultations/:id/call", h.Consultation.CallInfo)
		authed.POST("/consultations/:id/cancel", h.Consultation.Cancel)
		authed.POST("/consultations/:id/accept", middleware.RequireRole("technician"), h.Consultation.Accept)
		authed.POST("/consultations/:id/reject", middleware.RequireRole("technician"), h.Consultation.Reject)
		authed.POST("/consultations/:id/start", h.Consultation.Start)
		authed.POST("/consultations/:id/end", h.Consultation.End)
		authed.POST("/consultations/:id/payment", h.Consultation.Pay)
		authed.POST("/consultations/:id/escalate", h.Consultation.Escalate)
		authed.POST("/consultations/:id/rating", h.Consultation.Rating)

		// WebRTC ICE server configuration (STUN + short-lived TURN credential) for the
		// peer-to-peer video call — see internal/handler/webrtc_handler.go.
		authed.GET("/webrtc/ice-servers", h.WebRTC.IceServers)

		authed.POST("/payments/orders", h.Payment.CreateOrder)
		authed.POST("/payments/confirm", h.Payment.Confirm)
		authed.POST("/payments/fail", h.Payment.Fail)
		authed.GET("/payments/history", h.Payment.History)
		authed.POST("/payments/:id/refund", middleware.RequireRole("admin"), h.Payment.Refund)

		authed.GET("/wallet", h.Wallet.Balance)
		authed.GET("/wallet/transactions", h.Wallet.History)
		authed.POST("/wallet/credit", middleware.RequireRole("admin"), h.Wallet.Credit)
		authed.POST("/wallet/debit", h.Wallet.Debit)

		authed.POST("/reviews", h.Review.Create)

		// Disputes — raise/track/evidence. Resolution is admin-only (hidden /admin panel).
		authed.POST("/disputes", h.Dispute.Raise)
		authed.GET("/disputes/me", h.Dispute.ListMine)
		authed.GET("/disputes/:id", h.Dispute.Get)
		authed.POST("/disputes/:id/evidence", h.Dispute.AddEvidence)

		authed.POST("/ai/sessions", h.AI.StartSession)
		authed.POST("/ai/sessions/:id/messages", h.AI.SendMessage)
		authed.GET("/ai/sessions/:id/messages", h.AI.History)
        authed.POST("/ai/transcribe", h.AI.Transcribe)
		authed.GET("/notifications", h.Notification.List)
		authed.PATCH("/notifications/:id/read", h.Notification.MarkRead)
	}

	return r
}

// secureHeaders sets the standard defensive headers on every response: prevents
// MIME-sniffing, blocks this API from being framed, disables the legacy XSS
// auditor footgun, and opts out of sending a Referer to third parties. HSTS is
// added too — harmless over plain HTTP in local dev, and exactly what you want once
// a reverse proxy terminates TLS in front of this service in production.
func secureHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "0")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
		c.Next()
	}
}

// corsMiddleware allows the Flutter app (mobile, emulator, or web/Chrome) to call this
// API from any origin during development. Before shipping to production, replace the
// wildcard with your actual app/web origin(s).
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, Accept")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}