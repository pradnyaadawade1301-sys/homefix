package main

import (
	"context"
	"log"
	"time"

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

	// Self-healing startup migration: the 016_arrival_otp migration file was
	// missing its .sql extension so it never got picked up by earlier deploys,
	// leaving bookings.otp_code / otp_verified_at missing in production. This
	// runs on every boot and is a safe no-op once the columns already exist.
	if _, err := pool.Exec(context.Background(),
		`ALTER TABLE bookings ADD COLUMN IF NOT EXISTS otp_code VARCHAR(6);
		 ALTER TABLE bookings ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMP NULL;`); err != nil {
		log.Fatalf("startup: failed to ensure otp columns exist: %v", err)
	}

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
	// Razorpay replaces the UpiService above for the customer-facing payment flow
	// (order creation / confirm / refund / dispute-refund / admin refund).
	// upiService itself is kept around only in case anything elsewhere still
	// references it directly, but it's no longer wired into any handler below.
	razorpayService := service.NewRazorpayService(
		cfg.RazorpayKeyID, cfg.RazorpayKeySecret, cfg.PlatformCommissionPercent, cfg.GSTPercent, cfg.RepeatCustomerDiscountPercent,
		paymentRepo, bookingRepo, techRepo, walletRepo,
	)

	// fcmService is never nil: in-app notification rows must always be written even
	// when Firebase/push isn't configured. When push isn't available, SendToUser
	// simply skips the actual FCM send and records the in-app notification only.
	fcmService := service.NewFirebaseServiceOrDegraded(context.Background(), cfg.FirebaseCredentialsPath, cfg.FirebaseProjectID, notifRepo, userRepo)
	if cfg.FirebaseCredentialsPath == "" || cfg.FirebaseProjectID == "" {
		log.Println("warning: FIREBASE_CREDENTIALS_PATH/FIREBASE_PROJECT_ID not set, push notifications disabled (in-app notifications still work)")
	}

	// ---- Domain services ----
	authService := service.NewAuthService(userRepo, mailService, cfg.JWTAccessSecret, cfg.JWTRefreshSecret, cfg.JWTAccessTTLMin, cfg.JWTRefreshTTLHrs, cfg.GoogleClientID)
	userService := service.NewUserService(userRepo)
	techService := service.NewTechnicianService(techRepo, catRepo, reviewRepo)
	bookingService := service.NewBookingService(bookingRepo, catRepo, techRepo, paymentRepo, fcmService)
	consultService := service.NewConsultationService(consultRepo, techRepo, bookingService, reviewRepo, fcmService)
	walletService := service.NewWalletService(walletRepo)
	reviewService := service.NewReviewService(reviewRepo, bookingRepo)
	disputeService := service.NewDisputeService(disputeRepo, bookingRepo, razorpayService, paymentRepo)
	inventoryService := service.NewInventoryService(inventoryRepo)
	cmsService := service.NewCmsService(cmsRepo)
	analyticsService := service.NewAnalyticsService(analyticsRepo)
	adminService := service.NewAdminService(userRepo, techRepo, techService, bookingRepo, paymentRepo)

	// ---- Handlers ----
	financeHandler := handler.NewFinanceHandler(paymentRepo, walletRepo, upiService)
	adminAPIHandler := handler.NewAdminAPIHandler(userRepo, bookingRepo, techRepo, paymentRepo)

	handlers := &router.Handlers{
		Auth:         handler.NewAuthHandler(authService, cfg.Env),
		User:         handler.NewUserHandler(userService),
		Category:     handler.NewCategoryHandler(catRepo),
		Technician:   handler.NewTechnicianHandler(techService),
		Booking:      handler.NewBookingHandler(bookingService),
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

	// Background poller — periodically promotes "confirmed" scheduled consultations
	// whose slot time has arrived into "ringing" (see ConsultationService.
	// PromoteDueScheduled), so a "Schedule for later" call actually starts on time
	// even if neither app is open at that exact moment. 30s granularity is plenty
	// for a consultation slot (minutes-scale precision, not seconds).
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			promoted, err := consultService.PromoteDueScheduled(context.Background())
			if err != nil {
				log.Printf("scheduled-consultation poller: error: %v", err)
				continue
			}
			if promoted > 0 {
				log.Printf("scheduled-consultation poller: promoted %d consultation(s) to ringing", promoted)
			}
		}
	}()

	log.Printf("HomeFix Live backend starting on :%s (env=%s)", cfg.Port, cfg.Env)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
