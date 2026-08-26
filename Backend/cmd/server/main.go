package main

import (
	"context"
	"log"

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

	rdb := cache.New(cfg.RedisURL)
	if rdb.Enabled() {
		log.Println("connected to Redis (caching + rate limiting active)")
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
		cfg.UpiPayeeVPA, cfg.UpiPayeeName, cfg.PlatformCommissionPercent, cfg.GSTPercent,
		paymentRepo, bookingRepo, techRepo, walletRepo,
	)

	var fcmService *service.FirebaseService
	if cfg.FirebaseCredentialsPath != "" && cfg.FirebaseProjectID != "" {
		fcmService, err = service.NewFirebaseService(context.Background(), cfg.FirebaseCredentialsPath, cfg.FirebaseProjectID, notifRepo, userRepo)
		if err != nil {
			log.Printf("warning: firebase init failed, push notifications disabled: %v", err)
			fcmService = nil
		}
	} else {
		log.Println("warning: FIREBASE_CREDENTIALS_PATH/FIREBASE_PROJECT_ID not set, push notifications disabled")
	}

	// ---- Domain services ----
	authService := service.NewAuthService(userRepo, cfg.JWTAccessSecret, cfg.JWTRefreshSecret, cfg.JWTAccessTTLMin, cfg.JWTRefreshTTLHrs)
	userService := service.NewUserService(userRepo)
	techService := service.NewTechnicianService(techRepo, catRepo, reviewRepo)
	bookingService := service.NewBookingService(bookingRepo, catRepo, techRepo, fcmService)
	consultService := service.NewConsultationService(consultRepo, techRepo, bookingService, reviewRepo, fcmService)
	walletService := service.NewWalletService(walletRepo)
	reviewService := service.NewReviewService(reviewRepo, bookingRepo)
	disputeService := service.NewDisputeService(disputeRepo, bookingRepo, upiService, paymentRepo)
	inventoryService := service.NewInventoryService(inventoryRepo)
	cmsService := service.NewCmsService(cmsRepo)
	analyticsService := service.NewAnalyticsService(analyticsRepo)
	adminService := service.NewAdminService(userRepo, techRepo, techService, bookingRepo, paymentRepo)

	// ---- Handlers ----
	handlers := &router.Handlers{
		Auth:         handler.NewAuthHandler(authService, cfg.Env),
		User:         handler.NewUserHandler(userService),
		Category:     handler.NewCategoryHandler(catRepo),
		Technician:   handler.NewTechnicianHandler(techService),
		Booking:      handler.NewBookingHandler(bookingService),
		Payment:      handler.NewPaymentHandler(upiService, fcmService),
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
		Upi:       upiService,
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
