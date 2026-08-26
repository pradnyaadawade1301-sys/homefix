package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

type Config struct {
	Port  string
	Env   string
	DBUrl string

	JWTAccessSecret  string
	JWTRefreshSecret string
	JWTAccessTTLMin  int
	JWTRefreshTTLHrs int

	// RedisURL backs both rate limiting (login/signup/OTP brute-force protection)
	// and response caching (category list, technician availability). Empty disables
	// both — the app still runs, just without either (see internal/cache).
	RedisURL string

	GroqAPIKey string
	// GroqAPIKeys holds all configured Groq keys for automatic rotation (see
	// internal/service/groq_service.go keyRing). Populated by splitting
	// GROQ_API_KEY on commas; falls back to a single-element slice with
	// GroqAPIKey if no commas are present. Supports any number of keys (e.g.
	// 6), cycling back to the first once all have been tried.
	GroqAPIKeys []string
	GroqModel   string
	GroqAPIURL  string

	UpiPayeeVPA  string
	UpiPayeeName string

	// PlatformCommissionPercent is deducted from a completed booking's payment before
	// the rest is credited to the technician's wallet as their earning (see
	// internal/service/upi_service.go ConfirmPayment).
	PlatformCommissionPercent float64

	// GSTPercent is added on top of the technician's billed (base) amount to
	// arrive at the customer's total payable amount (see
	// internal/service/upi_service.go CreateOrder). Defaults to 18% (standard
	// GST rate for services in India) — override via GST_PERCENT env var.
	GSTPercent float64

	FirebaseCredentialsPath string
	FirebaseProjectID       string

	// Local-disk file storage for technician KYC uploads (government ID, profile photo).
	// Swap-in point for AWS S3 / S3-compatible storage: replace UploadDir handling in
	// internal/handler/upload_handler.go with an S3 PutObject call and set PublicBaseURL
	// to the bucket's public/CDN URL — no other code needs to change.
	UploadDir     string
	PublicBaseURL string

	// WebRTC ICE servers for the peer-to-peer video call (see internal/handler/call_handler.go
	// for the signaling relay, internal/utils/turn_credentials.go for how TURN creds are minted).
	StunURLs      []string
	TurnURL       string
	TurnSecret    string
	TurnRealm     string
	TurnTTLSecond int
}

// mustGet fails fast on startup if a required secret is missing.
// No silent fallback to a default value for anything security-sensitive.
func mustGet(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic(fmt.Sprintf("config: required environment variable %s is not set", key))
	}
	return v
}

func getOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func Load() *Config {
	_ = godotenv.Load() // ok if .env missing in container (env vars injected instead)

	accessTTL, err := strconv.Atoi(getOr("JWT_ACCESS_TTL_MIN", "15"))
	if err != nil {
		accessTTL = 15
	}
	refreshTTL, err := strconv.Atoi(getOr("JWT_REFRESH_TTL_HOURS", "720"))
	if err != nil {
		refreshTTL = 720
	}
	turnTTL, err := strconv.Atoi(getOr("TURN_TTL_SECONDS", "3600"))
	if err != nil {
		turnTTL = 3600
	}
	commissionPct, err := strconv.ParseFloat(getOr("PLATFORM_COMMISSION_PERCENT", "15"), 64)
	if err != nil {
		commissionPct = 15
	}
	gstPct, err := strconv.ParseFloat(getOr("GST_PERCENT", "18"), 64)
	if err != nil {
		gstPct = 18
	}

	return &Config{
		Port:  getOr("PORT", "8080"),
		Env:   getOr("ENV", "development"),
		DBUrl: mustGet("DATABASE_URL"),

		JWTAccessSecret:  mustGet("JWT_ACCESS_SECRET"),
		JWTRefreshSecret: mustGet("JWT_REFRESH_SECRET"),
		JWTAccessTTLMin:  accessTTL,
		JWTRefreshTTLHrs: refreshTTL,

		RedisURL: getOr("REDIS_URL", "redis://redis:6379/0"),

		GroqAPIKey: mustGet("GROQ_API_KEY"),
		GroqAPIKeys: func() []string {
			raw := mustGet("GROQ_API_KEY")
			parts := strings.Split(raw, ",")
			keys := make([]string, 0, len(parts))
			for _, p := range parts {
				p = strings.TrimSpace(p)
				if p != "" {
					keys = append(keys, p)
				}
			}
			return keys
		}(),
		GroqModel:  getOr("GROQ_MODEL", "llama-3.3-70b-versatile"),
		GroqAPIURL: getOr("GROQ_API_URL", "https://api.groq.com/openai/v1/chat/completions"),

		UpiPayeeVPA:  getOr("UPI_PAYEE_VPA", "homefixlive@okaxis"),
		UpiPayeeName: getOr("UPI_PAYEE_NAME", "HomeFix Live"),

		FirebaseCredentialsPath: getOr("FIREBASE_CREDENTIALS_PATH", ""),
		FirebaseProjectID:       getOr("FIREBASE_PROJECT_ID", ""),

		UploadDir:     getOr("UPLOAD_DIR", "./uploads"),
		PublicBaseURL: getOr("PUBLIC_BASE_URL", "http://localhost:8080"),

		StunURLs:      strings.Split(getOr("STUN_URLS", "stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302"), ","),
		TurnURL:       getOr("TURN_URL", ""),
		TurnSecret:    getOr("TURN_SECRET", ""),
		TurnRealm:     getOr("TURN_REALM", "homefixlive.com"),
		TurnTTLSecond: turnTTL,

		PlatformCommissionPercent: commissionPct,
		GSTPercent:                gstPct,
	}
}
