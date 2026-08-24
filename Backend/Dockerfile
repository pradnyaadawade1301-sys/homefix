# ---- Build stage ----
FROM golang:1.22-alpine AS builder
WORKDIR /app

ENV GOTOOLCHAIN=auto

RUN apk add --no-cache git

COPY go.mod ./
RUN go mod download 2>/dev/null || true
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o /homefix-server ./cmd/server

# ---- Run stage ----
FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /homefix-server /app/homefix-server
EXPOSE 8080
ENTRYPOINT ["/app/homefix-server"]