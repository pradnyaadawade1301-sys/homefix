package main

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/admin"
	"homefix-backend/internal/cache"
	"homefix-backend/internal/config"
	"homefix-backend/internal/db"
	"homefix-backend/internal/handler"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/router"
	"homefix-backend/internal/service"
)

func main() {
	cfg := config.Load()

	pool, err := db.NewPool(cfg.DBUrl)
	if err != nil {
		log.Fatalf("startup: %v", err)
	}
	defer pool.Close()
	log.Println("connected to Postgres")

	// Self-healing startup migrations run in the background, AFTER the HTTP
	// server has already bound its port (see bottom of main). Render's port
	// scanner has a ~50s timeout; running these ALTER/INSERT statements
	// before r.Run() risked pushing "Listening on :PORT" past that window
	// on a slow/cold-started free-tier Postgres instance, which made Render
	// mark otherwise-healthy deploys as Failed. Each statement is still a
	// safe no-op once already applied, so running it a few seconds after
	// boot instead of before is harmless.
	go runStartupMigrations(pool)

	rdb := cache.New(cfg.RedisURL) // no-op now — Redis removed, see internal/cache
	mailService := service.NewMailService(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPass, cfg.SMTPFrom)
	if mailService.Enabled() {
		log.Println("SMTP configured — email OTP will be sent via", cfg.SMTPHost)
	} else {
		log.Println("SMTP not configured — email OTP will be logged instead of sent (set SMTP_USER/SMTP_PASS in .env)")
	}

	// ---- Repositories ----
	userRepo := repository.NewUserRepository(pool)
	catRepo := repository.NewCategoryRepository(pool)
	techRepo := repository.NewTechnicianRepository(pool)
	bookingRepo := repository.NewBookingRepository(pool)
	consultRepo := repository.NewConsultationRepository(pool)
	paymentRepo := repository.NewPaymentRepository(pool)
	walletRepo := repository.NewWalletRepository(pool)
	reviewRepo := repository.NewReviewRepository(pool)
	aiRepo := repository.NewAIRepository(pool)
	notifRepo := repository.NewNotificationRepository(pool)
	disputeRepo := repository.NewDisputeRepository(pool)
	inventoryRepo := repository.NewInventoryRepository(pool)
	cmsRepo := repository.NewCmsRepository(pool)
	auditRepo := repository.NewAuditRepository(pool)
	analyticsRepo := repository.NewAnalyticsRepository(pool)

	// ---- External services ----
	groqService := service.NewGroqService(cfg.GroqAPIKeys, cfg.GroqModel, cfg.GroqAPIURL, aiRepo)
	upiService := service.NewUpiService(
		cfg.UpiPayeeVPA, cfg.UpiPayeeName, cfg.PlatformCommissionPercent, cfg.GSTPercent, cfg.RepeatCustomerDiscountPercent,
		paymentRepo, bookingRepo, techRepo, walletRepo,
	)
	// fcmService is never nil: in-app notification rows must always be written even
	// when Firebase/push isn't configured. When push isn't available, SendToUser
	// simply skips the actual FCM send and records the in-app notification only.
	// Created before razorpayService (below) since payment confirmation notifies
	// both customer and technician once a payment is verified.
	fcmService := service.NewFirebaseServiceOrDegraded(context.Background(), cfg.FirebaseCredentialsPath, cfg.FirebaseProjectID, notifRepo, userRepo)
	if cfg.FirebaseCredentialsPath == "" || cfg.FirebaseProjectID == "" {
		log.Println("warning: FIREBASE_CREDENTIALS_PATH/FIREBASE_PROJECT_ID not set, push notifications disabled (in-app notifications still work)")
	}

	// Razorpay replaces the UpiService above for the customer-facing payment flow
	// (order creation / confirm / refund / dispute-refund / admin refund).
	// upiService itself is kept around only in case anything elsewhere still
	// references it directly, but it's no longer wired into any handler below.
	razorpayService := service.NewRazorpayService(
		cfg.RazorpayKeyID, cfg.RazorpayKeySecret, cfg.PlatformCommissionPercent, cfg.GSTPercent, cfg.RepeatCustomerDiscountPercent,
		cfg.PlatformFeeAmount, cfg.VisitFeeAmount,
		paymentRepo, bookingRepo, techRepo, walletRepo, fcmService,
	)

	// ---- Domain services ----
	authService := service.NewAuthService(userRepo, mailService, cfg.JWTAccessSecret, cfg.JWTRefreshSecret, cfg.JWTAccessTTLMin, cfg.JWTRefreshTTLHrs, cfg.GoogleClientID)
	userService := service.NewUserService(userRepo)
	techService := service.NewTechnicianService(techRepo, catRepo, reviewRepo)
	bookingService := service.NewBookingService(bookingRepo, catRepo, techRepo, paymentRepo, fcmService)
	consultService := service.NewConsultationService(consultRepo, techRepo, bookingService, reviewRepo, aiRepo, fcmService)
	walletService := service.NewWalletService(walletRepo)
	reviewService := service.NewReviewService(reviewRepo, bookingRepo)
	disputeService := service.NewDisputeService(disputeRepo, bookingRepo, consultRepo, techRepo, razorpayService, paymentRepo)
	inventoryService := service.NewInventoryService(inventoryRepo)
	cmsService := service.NewCmsService(cmsRepo)
	analyticsService := service.NewAnalyticsService(analyticsRepo)
	adminService := service.NewAdminService(userRepo, techRepo, techService, bookingRepo, paymentRepo)

	// ---- Handlers ----
	financeHandler := handler.NewFinanceHandler(paymentRepo, walletRepo, upiService)
	adminAPIHandler := handler.NewAdminAPIHandler(userRepo, bookingRepo, techRepo, paymentRepo, disputeService)

	handlers := &router.Handlers{
		Auth:         handler.NewAuthHandler(authService, cfg.Env),
		User:         handler.NewUserHandler(userService),
		Category:     handler.NewCategoryHandler(catRepo),
		Technician:   handler.NewTechnicianHandler(techService),
		Booking:      handler.NewBookingHandler(bookingService, cfg.StunURLs, cfg.TurnURL, cfg.TurnSecret, cfg.TurnTTLSecond),
		Payment:      handler.NewPaymentHandler(razorpayService, fcmService),
		Wallet:       handler.NewWalletHandler(walletService),
		Review:       handler.NewReviewHandler(reviewService),
		AI:           handler.NewAIHandler(groqService),
		Notification: handler.NewNotificationHandler(notifRepo),
		Upload:       handler.NewUploadHandler(cfg.UploadDir, cfg.PublicBaseURL),
		Call:         handler.NewCallHandler(bookingRepo, techRepo, consultRepo, cfg.JWTAccessSecret),
		Consultation: handler.NewConsultationHandler(consultService, cfg.StunURLs, cfg.TurnURL, cfg.TurnSecret, cfg.TurnTTLSecond),
		WebRTC:       handler.NewWebRTCHandler(cfg.StunURLs, cfg.TurnURL, cfg.TurnSecret, cfg.TurnTTLSecond),
		Dispute:      handler.NewDisputeHandler(disputeService),
		Cms:          handler.NewCmsHandler(cmsService),
		Finance:      financeHandler,
		AdminAPI:     adminAPIHandler,
	}

	r := router.Setup(handlers, cfg.JWTAccessSecret, cfg.UploadDir, rdb)

	// Hidden admin web panel — /admin, never linked from or reachable via the
	// Flutter app's own API surface. See internal/admin's package doc comment.
	admin.RegisterRoutes(r, &admin.Deps{
		Admin:     adminService,
		Dispute:   disputeService,
		Inventory: inventoryService,
		Cms:       cmsService,
		Analytics: analyticsService,
		Upi:       upiService, // admin panel legacy field; kept pointing at UpiService, unused for new payments
		Category:  catRepo,
		Audit:     auditRepo,
		JWTSecret: cfg.JWTAccessSecret,
		Cache:     rdb,
	})

	log.Printf("HomeFix Live backend starting on :%s (env=%s)", cfg.Port, cfg.Env)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}

// runStartupMigrations applies the self-healing schema fixes described above.
// It runs in a goroutine after the server starts listening, so a slow DB
// never delays port binding / Render's health check. Failures here are
// logged, not fatal — the server keeps serving traffic either way, and the
// statements are safe to retry on the next boot.
func runStartupMigrations(pool *pgxpool.Pool) {
	ctx := context.Background()

	// 016_arrival_otp — file was missing its .sql extension so it never got
	// picked up by earlier deploys, leaving bookings.otp_code /
	// otp_verified_at missing in production. Safe no-op once columns exist.
	if _, err := pool.Exec(ctx,
		`ALTER TABLE bookings ADD COLUMN IF NOT EXISTS otp_code VARCHAR(6);
		 ALTER TABLE bookings ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMP NULL;
		 ALTER TABLE consultations ADD COLUMN IF NOT EXISTS decline_reason TEXT;`); err != nil {
		log.Printf("startup migration: failed to ensure otp columns exist: %v", err)
	}

	// 030_seed_more_categories_2 — only ever ran via `make migrate` against
	// the local Docker Postgres container; Render's deploy just runs the
	// compiled binary and never applies files under migrations/. Safe no-op
	// once the rows already exist.
	if _, err := pool.Exec(ctx,
		`INSERT INTO categories (name, description, is_active) VALUES
			('Civil Work',          'Masonry, tiling, and construction work', true),
			('Fabrication',         'Metal fabrication and welding work',     true),
			('POP / False Ceiling', 'POP work and false ceiling installation', true),
			('General Repair',      'General home repair and maintenance',    true)
		 ON CONFLICT (name) DO NOTHING;`); err != nil {
		log.Printf("startup migration: failed to seed new categories: %v", err)
	}

	// 031_warranty_description — same "Render never applies migrations/
	// files" issue as above. Adds the technician's free-text "what does
	// this warranty cover" note. Safe no-op once the column already exists.
	if _, err := pool.Exec(ctx,
		`ALTER TABLE bookings ADD COLUMN IF NOT EXISTS warranty_description TEXT NULL;`); err != nil {
		log.Printf("startup migration: failed to ensure warranty_description column exists: %v", err)
	}

	log.Println("startup migrations: done")
}