package repository

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type NotificationRepository struct {
	db *pgxpool.Pool
}

func NewNotificationRepository(db *pgxpool.Pool) *NotificationRepository {
	return &NotificationRepository{db: db}
}

func (r *NotificationRepository) Create(ctx context.Context, n *models.Notification, sentViaFCM bool) (*models.Notification, error) {
	dataJSON, err := json.Marshal(n.Data)
	if err != nil {
		return nil, err
	}
	err = r.db.QueryRow(ctx, `
		INSERT INTO notifications (user_id, title, body, data, sent_via_fcm)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, is_read, created_at
	`, n.UserID, n.Title, n.Body, dataJSON, sentViaFCM).Scan(&n.ID, &n.IsRead, &n.CreatedAt)
	if err != nil {
		return nil, err
	}
	n.SentViaFCM = sentViaFCM
	return n, nil
}

func (r *NotificationRepository) ListByUser(ctx context.Context, userID string) ([]models.Notification, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, title, body, data, is_read, sent_via_fcm, created_at
		FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Notification
	for rows.Next() {
		var n models.Notification
		var raw []byte
		if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Body, &raw, &n.IsRead, &n.SentViaFCM, &n.CreatedAt); err != nil {
			return nil, err
		}
		if len(raw) > 0 {
			_ = json.Unmarshal(raw, &n.Data)
		}
		out = append(out, n)
	}
	return out, nil
}

func (r *NotificationRepository) MarkRead(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, `UPDATE notifications SET is_read = true WHERE id = $1`, id)
	return err
}