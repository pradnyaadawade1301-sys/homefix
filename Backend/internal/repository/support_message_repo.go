package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type SupportMessageRepository struct {
	db *pgxpool.Pool
}

func NewSupportMessageRepository(db *pgxpool.Pool) *SupportMessageRepository {
	return &SupportMessageRepository{db: db}
}

func (r *SupportMessageRepository) Create(ctx context.Context, m *models.SupportMessage) (*models.SupportMessage, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO support_messages (user_id, sender_role, message, attachment_url, attachment_type)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, created_at
	`, m.UserID, m.SenderRole, m.Message, m.AttachmentURL, m.AttachmentType).Scan(&m.ID, &m.CreatedAt)
	if err != nil {
		return nil, err
	}
	return m, nil
}

// ListByUser returns the full thread for one user, oldest first.
func (r *SupportMessageRepository) ListByUser(ctx context.Context, userID string) ([]models.SupportMessage, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, sender_role, message, attachment_url, attachment_type, created_at
		FROM support_messages
		WHERE user_id = $1
		ORDER BY created_at ASC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.SupportMessage
	for rows.Next() {
		var m models.SupportMessage
		if err := rows.Scan(&m.ID, &m.UserID, &m.SenderRole, &m.Message, &m.AttachmentURL, &m.AttachmentType, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ListChats — one row per user who has ever messaged support, most
// recently active first, for the admin panel's support inbox.
func (r *SupportMessageRepository) ListChats(ctx context.Context) ([]models.SupportChatSummary, error) {
	rows, err := r.db.Query(ctx, `
		SELECT latest.user_id, COALESCE(u.name, 'Unknown'), COALESCE(u.phone, ''),
		       COALESCE(latest.message, ''), latest.created_at, latest.sender_role
		FROM (
			SELECT DISTINCT ON (user_id) user_id, message, created_at, sender_role
			FROM support_messages
			ORDER BY user_id, created_at DESC
		) latest
		JOIN users u ON u.id = latest.user_id
		ORDER BY latest.created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.SupportChatSummary
	for rows.Next() {
		var c models.SupportChatSummary
		if err := rows.Scan(&c.UserID, &c.UserName, &c.UserPhone, &c.LastMessage, &c.LastMessageAt, &c.LastSenderRole); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// HasAdminMessageSince reports whether support (human or automatic) has
// already replied to this user since the given time.
func (r *SupportMessageRepository) HasAdminMessageSince(ctx context.Context, userID string, since time.Time) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM support_messages
			WHERE user_id = $1 AND sender_role = 'admin' AND created_at > $2
		)
	`, userID, since).Scan(&exists)
	return exists, err
}