// Package cache previously wrapped Redis for response caching and rate limiting.
// Redis has been removed from this project's infrastructure, so this is now a
// permanent no-op shim: every Get is a miss, every Allow permits the request.
// Kept only so call sites elsewhere in the codebase (rate-limit middleware, the
// admin package) that already take a *cache.Client keep compiling unchanged.
package cache

import (
	"context"
	"time"
)

type Client struct{}

// New used to connect to Redis using redisURL. It no longer does anything —
// Redis has been removed — and always returns the disabled no-op client.
func New(redisURL string) *Client {
	return &Client{}
}

// Disabled returns a no-op client. Kept for existing callers (e.g. tests).
func Disabled() *Client {
	return &Client{}
}

func (c *Client) Enabled() bool { return false }

func (c *Client) Get(ctx context.Context, key string) (string, bool) {
	return "", false
}

func (c *Client) Set(ctx context.Context, key, value string, ttl time.Duration) {}

func (c *Client) Del(ctx context.Context, key string) {}

// Allow always permits the request now that there's no Redis-backed counter.
// Rate limiting is effectively disabled — see this file's doc comment.
func (c *Client) Allow(ctx context.Context, key string, limit int, window time.Duration) bool {
	return true
}
