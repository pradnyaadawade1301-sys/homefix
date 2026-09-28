package service

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"
	"unicode"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// SupportService is the general "Contact Support" live chat — reachable
// from the Profile screen, talking directly to HomeFix support without
// first needing to raise a dispute against a specific booking. See
// DisputeService for the booking-scoped equivalent.
type SupportService struct {
	repo *repository.SupportMessageRepository
	ai   SupportAI // optional; nil means canned replies only
}

// SupportAI is the slice of GroqService the support chat needs, kept as an
// interface so the chat still works (with canned replies) if AI is not
// configured or fails.
type SupportAI interface {
	Chat(ctx context.Context, system string, turns []ChatTurn) (string, error)
}

// SetAI enables AI-written replies for messages the FAQ rules don't cover.
func (s *SupportService) SetAI(ai SupportAI) { s.ai = ai }

const supportAISystemPrompt = `You are the customer support assistant for HomeFix, a home-services app where customers book technicians (plumbing, electrical, AC, appliance repair, etc).
Reply to the customer's latest message in simple, clear, polite English (customers may write in Hindi/Hinglish; understand it, but answer in English).
Rules:
- Keep it to 1-3 short sentences. Plain text only, no markdown, no lists.
- Be empathetic. If they report a problem or poor service, apologise, and ask for the one most useful detail (booking/service involved, what went wrong) or invite photos/video.
- Ask at most one question. Do not repeat what was already said earlier in the conversation.
- Never promise refunds, compensation, discounts, technician visits, timelines or outcomes, and never invent policies, prices or phone numbers.
- If the issue needs action, say the support team will review it and follow up in this chat.`

func NewSupportService(repo *repository.SupportMessageRepository) *SupportService {
	return &SupportService{repo: repo}
}

// SendMessage — the logged-in user sends a message (and/or a photo/video
// attachment, already uploaded via POST /uploads) to support.
func (s *SupportService) SendMessage(ctx context.Context, userID, message, attachmentURL, attachmentType string) (*models.SupportMessage, error) {
	if strings.TrimSpace(message) == "" && attachmentURL == "" {
		return nil, errors.New("message or attachment is required")
	}
	if attachmentURL != "" && attachmentType != "image" && attachmentType != "video" {
		return nil, errors.New("attachment_type must be \"image\" or \"video\"")
	}
	m := &models.SupportMessage{
		UserID:     userID,
		SenderRole: "user",
		Message:    message,
	}
	if attachmentURL != "" {
		m.AttachmentURL = &attachmentURL
		m.AttachmentType = &attachmentType
	}
	saved, err := s.repo.Create(ctx, m)
	if err != nil {
		return nil, err
	}
	// Automatic reply — best effort. A failure here must never make the
	// customer's own message look like it failed to send.
	s.autoReply(ctx, userID, message)
	return saved, nil
}

// autoReplyAckWindow — the generic "we received your message" reply is sent
// worded in full only once per this window; follow-ups get a shorter one.
const autoReplyAckWindow = 10 * time.Minute

// autoReply saves an instant support reply (sender_role "admin", shown as
// "HomeFix Support" in the app) right after the customer's message, so the
// customer gets an answer without waiting for a human. Common questions get
// a specific answer; anything else gets a one-time acknowledgement. The app
// picks the reply up on its next fetch.
func (s *SupportService) autoReply(ctx context.Context, userID, message string) {
	// 1) Known question -> instant canned answer.
	if reply := matchFAQReply(message); reply != "" {
		s.saveAutoReply(ctx, userID, reply)
		return
	}
	// 2) Anything else -> AI-written reply, generated in the background so
	// sending the message isn't slowed down (the app picks the reply up on
	// its next poll). Falls back to a canned acknowledgement if AI is
	// unavailable.
	go func() {
		bg, cancel := context.WithTimeout(context.Background(), 25*time.Second)
		defer cancel()
		reply := s.aiReply(bg, userID)
		if reply == "" {
			reply = s.fallbackReply(bg, userID)
		}
		s.saveAutoReply(bg, userID, reply)
	}()
}

func (s *SupportService) saveAutoReply(ctx context.Context, userID, reply string) {
	if reply == "" {
		return
	}
	if _, err := s.repo.Create(ctx, &models.SupportMessage{
		UserID:     userID,
		SenderRole: "admin",
		Message:    reply,
	}); err != nil {
		log.Printf("support auto-reply: save failed: %v", err)
	}
}

// aiReply asks the AI for a reply based on the recent thread. Returns ""
// on any failure so the caller can fall back.
func (s *SupportService) aiReply(ctx context.Context, userID string) string {
	if s.ai == nil {
		return ""
	}
	msgs, err := s.repo.ListByUser(ctx, userID)
	if err != nil {
		log.Printf("support auto-reply: load thread failed: %v", err)
		return ""
	}
	if len(msgs) > 12 {
		msgs = msgs[len(msgs)-12:]
	}
	var turns []ChatTurn
	for _, m := range msgs {
		text := strings.TrimSpace(m.Message)
		if text == "" {
			text = "[customer sent a photo or video]"
		}
		role := "user"
		if m.SenderRole == "admin" {
			role = "assistant"
		}
		turns = append(turns, ChatTurn{Role: role, Content: text})
	}
	if len(turns) == 0 || turns[len(turns)-1].Role != "user" {
		return ""
	}
	reply, err := s.ai.Chat(ctx, supportAISystemPrompt, turns)
	if err != nil {
		log.Printf("support auto-reply: AI failed: %v", err)
		return ""
	}
	if len(reply) > 700 {
		reply = reply[:700]
	}
	return reply
}

// fallbackReply is used when AI is unavailable: full acknowledgement first,
// a shorter one for follow-ups within the window.
func (s *SupportService) fallbackReply(ctx context.Context, userID string) string {
	recent, err := s.repo.HasAdminMessageSince(ctx, userID, time.Now().Add(-autoReplyAckWindow))
	if err == nil && recent {
		return "Thanks, we have added this to your request. Please share any more details (you can attach photos or a video) and our support team will get back to you shortly."
	}
	return "Your message has been received. A HomeFix support agent will reply shortly."
}

// matchFAQReply returns a canned answer for common questions (English and
// Hinglish keywords), or "" when nothing matches.
func matchFAQReply(message string) string {
	t := strings.ToLower(message)
	has := func(words ...string) bool {
		for _, w := range words {
			if strings.Contains(t, w) {
				return true
			}
		}
		return false
	}
	// Short words match whole words only ("hi" must not match "this").
	words := strings.FieldsFunc(t, func(r rune) bool { return !unicode.IsLetter(r) })
	hasWord := func(ws ...string) bool {
		for _, w := range words {
			for _, x := range ws {
				if w == x {
					return true
				}
			}
		}
		return false
	}
	// Collapse repeated letters so "hii", "hiii", "hellooo" count as greetings.
	collapse := func(w string) string {
		var b strings.Builder
		var prev rune
		for _, r := range w {
			if r != prev {
				b.WriteRune(r)
			}
			prev = r
		}
		return b.String()
	}
	isGreeting := false
	for _, w := range words {
		switch collapse(w) {
		case "hi", "helo", "hey", "namaste", "namaskar":
			isGreeting = true
		}
	}
	switch {
	case has("cancel"):
		return "You can cancel a booking from My Bookings by opening the booking and choosing Cancel. If you need help with a cancellation or a refund, reply here and our team will assist you."
	case has("refund", "money back", "paise wapas", "paisa wapas"):
		return "Sorry for the trouble. We have noted your refund request and our support team will review it and get back to you here shortly."
	case hasWord("late") || has("nahi aaya", "nahi aya", "not arrived", "not come", "didn't come", "did not come", "abhi tak", "still waiting", "no show"):
		return "Sorry for the inconvenience. We are checking the technician's status for your booking and will update you here shortly."
	case has("reschedule", "change time", "change the time", "time change", "different time"):
		return "To change the time of a booking, please contact us with your booking details here and our team will help you reschedule."
	case has("payment", "charged", "overcharge", "extra charge") || hasWord("paid"):
		return "Sorry about the payment issue. Please share your booking details and what went wrong, and our team will look into it."
	case has("complaint", "complain", "bad service", "rude", "misbehav", "damage"):
		return "We are sorry about your experience. Your complaint has been noted; please describe what happened (you can also attach photos or a video) and our team will review it."
	case hasWord("issue", "issues", "problem", "problems", "help", "query", "doubt", "trouble") || has("not working", "kaam nahi", "dikkat", "samasya"):
		return "Sorry to hear that. Please tell us more about the issue: which service or booking is it about, and what went wrong? You can also attach photos or a video."
	case isGreeting && len(words) <= 3:
		return "Hello! Welcome to HomeFix Support. How can we help you today?"
	}
	return ""
}

// ListMessages — the logged-in user's own thread with support.
func (s *SupportService) ListMessages(ctx context.Context, userID string) ([]models.SupportMessage, error) {
	return s.repo.ListByUser(ctx, userID)
}

// AdminListChats / AdminListMessages / AdminReply — the hidden admin panel's
// side: browse every user who has messaged support, open one thread, reply.
func (s *SupportService) AdminListChats(ctx context.Context) ([]models.SupportChatSummary, error) {
	return s.repo.ListChats(ctx)
}

func (s *SupportService) AdminListMessages(ctx context.Context, userID string) ([]models.SupportMessage, error) {
	return s.repo.ListByUser(ctx, userID)
}

func (s *SupportService) AdminReply(ctx context.Context, userID, message, attachmentURL, attachmentType string) (*models.SupportMessage, error) {
	if strings.TrimSpace(message) == "" && attachmentURL == "" {
		return nil, errors.New("message or attachment is required")
	}
	if attachmentURL != "" && attachmentType != "image" && attachmentType != "video" {
		return nil, errors.New("attachment_type must be \"image\" or \"video\"")
	}
	m := &models.SupportMessage{
		UserID:     userID,
		SenderRole: "admin",
		Message:    message,
	}
	if attachmentURL != "" {
		m.AttachmentURL = &attachmentURL
		m.AttachmentType = &attachmentType
	}
	return s.repo.Create(ctx, m)
}