package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type DisputeMessageRepository struct {
	db *pgxpool.Pool
}

func NewDisputeMessageRepository(db *pgxpool.Pool) *DisputeMessageRepository {
	return &DisputeMessageRepository{db: db}
}

func (r *DisputeMessageRepository) Create(ctx context.Context, m *models.DisputeMessage) (*models.DisputeMessage, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO dispute_messages (dispute_id, sender_id, sender_role, message, attachment_url, attachment_type)
		VALUES ($1,$2,$3,$4,$5,$6)
		RETURNING id, created_at
	`, m.DisputeID, m.SenderID, m.SenderRole, m.Message, m.AttachmentURL, m.AttachmentType).Scan(&m.ID, &m.CreatedAt)
	if err != nil {
		return nil, err
	}
	return m, nil
}

// ListByDispute returns the full thread, oldest first, with the sender's
// display name resolved for admin-panel display (NULL sender_id -> "Support").
func (r *DisputeMessageRepository) ListByDispute(ctx context.Context, disputeID string) ([]models.DisputeMessage, error) {
	rows, err := r.db.Query(ctx, `
		SELECT dm.id, dm.dispute_id, dm.sender_id, dm.sender_role, dm.message, dm.created_at,
		       dm.attachment_url, dm.attachment_type,
		       COALESCE(u.name, 'Support')
		FROM dispute_messages dm
		LEFT JOIN users u ON u.id = dm.sender_id
		WHERE dm.dispute_id = $1
		ORDER BY dm.created_at ASC
	`, disputeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.DisputeMessage
	for rows.Next() {
		var m models.DisputeMessage
		if err := rows.Scan(&m.ID, &m.DisputeID, &m.SenderID, &m.SenderRole, &m.Message, &m.CreatedAt,
			&m.AttachmentURL, &m.AttachmentType, &m.SenderName); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}
