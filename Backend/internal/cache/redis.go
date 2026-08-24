// Package cache wraps Redis for two unrelated jobs that both want a fast shared
// store: response caching (category list, technician availability — data that's
// read constantly and changes rarely) and rate limiting (login/signup/OTP
// brute-force protection — see internal/middleware/ratelimit.go). Both degrade
// gracefully (cache misses / rate-limiting disabled) if Redis is unreachable,
// rather than taking the whole API down over a non-critical dependency.
package cache

import (
	"context"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

type Client struct {
	rdb *redis.Client
	ok  bool
}

// New connects to Redis. Never returns an error — a failed connection just means
// Get/Set/Allow become no-ops (cache-miss / always-allow) and a warning is logged,
// the same fail-open pattern this codebase already uses for optional dependencies
// (see FirebaseService init in cmd/server/main.go).
func New(redisURL string) *Client {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("warning: invalid REDIS_URL, caching/rate-limiting disabled: %v", err)
		return &Client{ok: false}
	}
	rdb := redis.NewClient(opt)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Printf("warning: could not connect to Redis, caching/rate-limiting disabled: %v", err)
		return &Client{ok: false}
	}
	return &Client{rdb: rdb, ok: true}
}

// Disabled returns a no-op client (every Get misses, every Allow permits) without
// attempting any connection — used by tests so they don't pay Redis's connect
// timeout when rate limiting/caching isn't what's under test.
func Disabled() *Client {
	return &Client{ok: false}
}

func (c *Client) Enabled() bool { return c.ok }

// Get returns (value, true) on a cache hit, ("", false) on a miss OR if Redis is
// disabled — callers always have a DB-query fallback path, so a miss is never an error.
func (c *Client) Get(ctx context.Context, key string) (string, bool) {
	if !c.ok {
		return "", false
	}
	val, err := c.rdb.Get(ctx, key).Result()
	if err != nil {
		return "", false
	}
	return val, true
}

func (c *Client) Set(ctx context.Context, key, value string, ttl time.Duration) {
	if !c.ok {
		return
	}
	_ = c.rdb.Set(ctx, key, value, ttl).Err()
}

func (c *Client) Del(ctx context.Context, key string) {
	if !c.ok {
		return
	}
	_ = c.rdb.Del(ctx, key).Err()
}

// Allow implements a fixed-window rate limit: at most `limit` calls per `window`
// for a given key (e.g. "ratelimit:login:<ip>"). Returns true (allowed) whenever
// Redis is unreachable — see package doc comment on why that's an intentional
// fail-open rather than fail-closed tradeoff.
func (c *Client) Allow(ctx context.Context, key string, limit int, window time.Duration) bool {
	if !c.ok {
		return true
	}
	count, err := c.rdb.Incr(ctx, key).Result()
	if err != nil {
		return true
	}
	if count == 1 {
		_ = c.rdb.Expire(ctx, key, window).Err()
	}
	return count <= int64(limit)
}
