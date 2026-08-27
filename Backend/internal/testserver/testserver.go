// Package testserver builds the exact same wiring as cmd/server/main.go (same
// repos, services, handlers, routes — including the hidden /admin panel) against
// a caller-supplied database, so integration tests exercise the real app instead
// of a hand-rolled stand-in. Used only by test/integration.
package testserver

import (
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/admin"
	"homefix-backend/internal/cache"
	"homefix-backend/internal/handler"
	"homefix-backend/internal/repository"
	"homefix-backend/internal/router"
	"homefix-backend/internal/service"
)

const (
	JWTAccessSecret  = "test-access-secret-do-not-use-in-prod"
	JWTRefreshSecret = "test-refresh-secret-do-not-use-in-prod"
)

// Server bundles the running engine plus a few pieces tests need direct DB/service
// access for (seeding fixtures, asserting DB state that has no API to read it back).
type Server struct {
	Engine      *gin.Engine
	Pool        *pgxpool.Pool
	UserRepo    *repository.UserRepository
	CatRepo     *repository.CategoryRepository
	TechRepo    *repository.TechnicianRepository
	BookingRepo *repository.BookingRepository
	PaymentRepo *repository.PaymentRepository
	WalletRepo  *repository.WalletRepository
}

func New(pool *pgxpool.Pool) *Server {
	gin.SetMode(gin.TestMode)

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

	groqService := service.NewGroqService([]string{"test-key"}, "test-model", "http://127.0.0.1:0/unused", aiRepo)
	upiService := service.NewUpiService("test@upi", "Test Payee", 15, 18, 5, paymentRepo, bookingRepo, techRepo, walletRepo)

	authService := service.NewAuthService(userRepo, service.NewMailService("", 0, "", "", ""), JWTAccessSecret, JWTRefreshSecret, 15, 720)
	userService := service.NewUserService(userRepo)
	techService := service.NewTechnicianService(techRepo, catRepo, reviewRepo)
	bookingService := service.NewBookingService(bookingRepo, catRepo, techRepo, paymentRepo, nil)
	consultService := service.NewConsultationService(consultRepo, techRepo, bookingService, reviewRepo, nil)
	walletService := service.NewWalletService(walletRepo)
	reviewService := service.NewReviewService(reviewRepo, bookingRepo)
	disputeService := service.NewDisputeService(disputeRepo, bookingRepo, upiService, paymentRepo)
	inventoryService := service.NewInventoryService(inventoryRepo)
	cmsService := service.NewCmsService(cmsRepo)
	analyticsService := service.NewAnalyticsService(analyticsRepo)
	adminService := service.NewAdminService(userRepo, techRepo, techService, bookingRepo, paymentRepo)

	handlers := &router.Handlers{
		Auth:         handler.NewAuthHandler(authService, "test"),
		User:         handler.NewUserHandler(userService),
		Category:     handler.NewCategoryHandler(catRepo),
		Technician:   handler.NewTechnicianHandler(techService),
		Booking:      handler.NewBookingHandler(bookingService),
		Payment:      handler.NewPaymentHandler(upiService, nil),
		Wallet:       handler.NewWalletHandler(walletService),
		Review:       handler.NewReviewHandler(reviewService),
		AI:           handler.NewAIHandler(groqService),
		Notification: handler.NewNotificationHandler(notifRepo),
		Upload:       handler.NewUploadHandler("/tmp/homefix-test-uploads", "http://localhost:8080"),
		Call:         handler.NewCallHandler(bookingRepo, techRepo, consultRepo, JWTAccessSecret),
		Consultation: handler.NewConsultationHandler(consultService, []string{"stun:stun.l.google.com:19302"}, "", "", 3600),
		WebRTC:       handler.NewWebRTCHandler([]string{"stun:stun.l.google.com:19302"}, "", "", 3600),
		Dispute:      handler.NewDisputeHandler(disputeService),
		Cms:          handler.NewCmsHandler(cmsService),
	}

	rdb := cache.Disabled() // rate limiting/caching aren't under test here — see cache.Disabled doc comment
	engine := router.Setup(handlers, JWTAccessSecret, "/tmp/homefix-test-uploads", rdb)

	admin.RegisterRoutes(engine, &admin.Deps{
		Admin:     adminService,
		Dispute:   disputeService,
		Inventory: inventoryService,
		Cms:       cmsService,
		Analytics: analyticsService,
		Upi:       upiService,
		Category:  catRepo,
		Audit:     auditRepo,
		JWTSecret: JWTAccessSecret,
		Cache:     rdb,
	})

	return &Server{
		Engine:      engine,
		Pool:        pool,
		UserRepo:    userRepo,
		CatRepo:     catRepo,
		TechRepo:    techRepo,
		BookingRepo: bookingRepo,
		PaymentRepo: paymentRepo,
		WalletRepo:  walletRepo,
	}
}