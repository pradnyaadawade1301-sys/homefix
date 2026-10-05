// Package cache previously wrapped Redis for response caching and rate limiting.
// Redis has been removed from this project's infrastructure, so this is now a
// permanent no-op shim: every Get is a miss, every Allow permits the request.
// Kept only so call sites elsewhere in the codebase (rate-limit middleware, the
// admin package) that already take a *cache.Client keep compiling unchanged.
package cache

import (
	"context"
	"sync"
	"time"
)

type rlEntry struct {
	count   int
	resetAt time.Time
}

type Client struct {
	mu      sync.Mutex
	buckets map[string]*rlEntry
}

// New used to connect to Redis using redisURL. It no longer does anything —
// Redis has been removed — and always returns the disabled no-op client.
func New(redisURL string) *Client {
	return &Client{buckets: map[string]*rlEntry{}}
}

// Disabled returns a no-op client. Kept for existing callers (e.g. tests).
func Disabled() *Client {
	return &Client{buckets: map[string]*rlEntry{}}
}

func (c *Client) Enabled() bool { return false }

func (c *Client) Get(ctx context.Context, key string) (string, bool) {
	return "", false
}

func (c *Client) Set(ctx context.Context, key, value string, ttl time.Duration) {}

func (c *Client) Del(ctx context.Context, key string) {}

// Allow is an in-memory fixed-window rate limiter (per process). It works on a
// single instance only; with multiple instances each keeps its own counters.
func (c *Client) Allow(ctx context.Context, key string, limit int, window time.Duration) bool {
	if c == nil {
		return true
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.buckets == nil {
		c.buckets = map[string]*rlEntry{}
	}
	now := time.Now()
	if len(c.buckets) > 10000 {
		for k, e := range c.buckets {
			if now.After(e.resetAt) {
				delete(c.buckets, k)
			}
		}
	}
	e, ok := c.buckets[key]
	if !ok || now.After(e.resetAt) {
		c.buckets[key] = &rlEntry{count: 1, resetAt: now.Add(window)}
		return true
	}
	if e.count >= limit {
		return false
	}
	e.count++
	return true
}
