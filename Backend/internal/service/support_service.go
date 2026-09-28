package service

import (
	"context"
	"errors"
	"strings"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

// SupportService is the general "Contact Support" live chat — reachable
// from the Profile screen, talking directly to HomeFix support without
// first needing to raise a dispute against a specific booking. See
// DisputeService for the booking-scoped equivalent.
type SupportService struct {
	repo *repository.SupportMessageRepository
}

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
	return s.repo.Create(ctx, m)
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
