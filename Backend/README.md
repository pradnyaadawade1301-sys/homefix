# HomeFix Live — Backend

Real, working Go backend for HomeFix Live. No mock/in-memory data — every read and
write hits Postgres. Covers auth, users, technicians, categories, bookings, AI
diagnosis (Groq), payments (Razorpay logic), wallet, reviews, and push notifications
(Firebase FCM).

## Stack

- Go 1.22, Gin, pgx (Postgres driver), JWT (access + refresh), bcrypt
- Postgres 16 (Docker)
- Groq API for AI diagnosis chat (real HTTP calls, no canned replies)
- Razorpay (order creation + signature verification — logic-complete, needs real
  API keys to go live)
- Firebase Admin SDK for FCM push notifications (needs a real service account JSON)

## Project layout

```
cmd/server/main.go          entry point, wires everything together
internal/config             env-driven config, fails fast on missing secrets
internal/db                 Postgres connection pool
internal/models              domain structs
internal/repository          real SQL queries (no mocks)
internal/service              business logic + external API integrations
internal/handler               HTTP handlers (Gin)
internal/middleware            JWT auth + role guard
internal/router                 route wiring
migrations/001_init.sql          full relational schema
```

## Setup

1. Copy `.env.example` to `.env` and fill in real values:
   - `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` — any long random string
   - `GROQ_API_KEY` — from https://console.groq.com
   - `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` / `RAZORPAY_WEBHOOK_SECRET` — from
     the Razorpay dashboard (test mode keys work fine to start)
   - `FIREBASE_CREDENTIALS_PATH` / `FIREBASE_PROJECT_ID` — download a service
     account JSON from Firebase Console → Project Settings → Service Accounts,
     place it at `./secrets/firebase-service-account.json`

2. Start everything with Docker:

```bash
mkdir -p secrets
# put firebase-service-account.json inside ./secrets/
make docker-up
```

This starts Postgres (with the schema in `migrations/001_init.sql` auto-applied on
first boot) and the Go app on `:8080`.

3. Check it's alive:

```bash
curl http://localhost:8080/health
```

## Running locally without Docker

```bash
# requires a local Postgres reachable via DATABASE_URL in .env
go mod tidy
make run
```

## Notes on "real, no mock data"

- Every table in `migrations/001_init.sql` is a real Postgres table with foreign
  keys, constraints, and a trigger that keeps technician `rating_avg` in sync when
  a review is inserted.
- `config.mustGet` panics on startup if a required secret (DB URL, JWT secrets,
  Groq key) is missing — there's no silent fallback to a fake default.
- The Groq service makes a real HTTP call to `api.groq.com` per message; there are
  no canned/hardcoded replies.
- The Razorpay service creates real orders against `api.razorpay.com` and verifies
  the HMAC-SHA256 signature exactly as Razorpay's docs specify. Payments will
  actually fail until you drop in live/test keys — that's expected, the logic is
  what's ready.
- Firebase FCM sends real pushes via the Admin SDK. If no service account is
  configured, the server still boots (logs a warning) and notifications are
  logged in-app only, with `sent_via_fcm = false`.

## Auth flow

- `POST /api/v1/auth/request-otp` — creates the user if new, generates a real
  6-digit OTP (crypto/rand), stores it with a 5-min expiry. In non-production env
  the OTP is echoed back in the response (`debug_otp`) so you can test end-to-end
  without an SMS gateway wired in yet — this is removed automatically once
  `ENV=production`.
- `POST /api/v1/auth/verify-otp` — verifies, activates the account, returns
  access + refresh JWTs.
- Technicians/admins can also set a password (`POST /auth/set-password`, once
  logged in) and log in later with `POST /auth/login`.

## Still to plug in for production

- Real SMS gateway for OTP delivery (currently OTP is DB-stored only; delivery is
  stubbed via the dev-mode `debug_otp` echo)
- Live Razorpay keys + webhook secret
- Firebase service account JSON
- Rate limiting / request throttling on public auth endpoints
