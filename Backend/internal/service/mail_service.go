// Package service also holds MailService: a thin wrapper around Go's standard
// net/smtp for sending the email-verification OTP via Gmail SMTP. Gmail is used
// because it's free — no paid transactional-email provider or API key needed —
// you just need a Gmail account with an "App Password" (Google Account ->
// Security -> 2-Step Verification -> App passwords), NOT your normal Gmail
// password. Set SMTP_USER to the Gmail address and SMTP_PASS to the 16-character
// app password in .env.
package service

import (
	"fmt"
	"log"
	"net/smtp"
)

type MailService struct {
	host string
	port int
	user string
	pass string
	from string
}

func NewMailService(host string, port int, user, pass, from string) *MailService {
	if from == "" {
		from = user
	}
	return &MailService{host: host, port: port, user: user, pass: pass, from: from}
}

// Enabled reports whether SMTP credentials are configured. When false,
// SendOTPEmail is a no-op that just logs — the same fail-open pattern used
// elsewhere in this codebase for optional external dependencies, so signup
// still works in local dev before Gmail credentials are set up.
func (m *MailService) Enabled() bool { return m.user != "" && m.pass != "" }

// SendOTPEmail sends the 6-digit email-verification code to `to`. If SMTP isn't
// configured, it logs the OTP instead of failing the request (mirrors how phone
// OTP is echoed back in the API response outside production).
func (m *MailService) SendOTPEmail(to, otp string) error {
	if !m.Enabled() {
		log.Printf("SMTP not configured — email OTP for %s is %s (dev fallback, not sent)", to, otp)
		return nil
	}

	subject := "Your HomeFix Live verification code"
	body := fmt.Sprintf(
		"Your verification code is: %s\r\n\r\nThis code expires in 10 minutes. If you didn't request this, you can ignore this email.",
		otp,
	)
	msg := []byte(fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s\r\n", m.from, to, subject, body))

	addr := fmt.Sprintf("%s:%d", m.host, m.port)
	auth := smtp.PlainAuth("", m.user, m.pass, m.host)
	if err := smtp.SendMail(addr, auth, m.from, []string{to}, msg); err != nil {
		log.Printf("warning: failed to send OTP email to %s: %v", to, err)
		return err
	}
	return nil
}