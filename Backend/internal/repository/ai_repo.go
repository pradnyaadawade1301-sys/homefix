package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type AIRepository struct {
	db *pgxpool.Pool
}

func NewAIRepository(db *pgxpool.Pool) *AIRepository {
	return &AIRepository{db: db}
}

func (r *AIRepository) CreateSession(ctx context.Context, userID string, categoryID *string) (*models.AIDiagnosisSession, error) {
	var s models.AIDiagnosisSession
	err := r.db.QueryRow(ctx, `
		INSERT INTO ai_diagnosis_sessions (user_id, category_id, status)
		VALUES ($1,$2,'active')
		RETURNING id, user_id, booking_id, category_id, status, created_at
	`, userID, categoryID).Scan(&s.ID, &s.UserID, &s.BookingID, &s.CategoryID, &s.Status, &s.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *AIRepository) GetSession(ctx context.Context, id string) (*models.AIDiagnosisSession, error) {
	var s models.AIDiagnosisSession
	err := r.db.QueryRow(ctx, `
		SELECT id, user_id, booking_id, category_id, status, created_at
		FROM ai_diagnosis_sessions WHERE id = $1
	`, id).Scan(&s.ID, &s.UserID, &s.BookingID, &s.CategoryID, &s.Status, &s.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &s, nil
}

func (r *AIRepository) AddMessage(ctx context.Context, sessionID, role, content string) (*models.AIDiagnosisMessage, error) {
	var m models.AIDiagnosisMessage
	err := r.db.QueryRow(ctx, `
		INSERT INTO ai_diagnosis_messages (session_id, role, content)
		VALUES ($1,$2,$3)
		RETURNING id, session_id, role, content, created_at
	`, sessionID, role, content).Scan(&m.ID, &m.SessionID, &m.Role, &m.Content, &m.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *AIRepository) ListMessages(ctx context.Context, sessionID string) ([]models.AIDiagnosisMessage, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, session_id, role, content, created_at
		FROM ai_diagnosis_messages WHERE session_id = $1 ORDER BY created_at ASC
	`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.AIDiagnosisMessage
	for rows.Next() {
		var m models.AIDiagnosisMessage
		if err := rows.Scan(&m.ID, &m.SessionID, &m.Role, &m.Content, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, nil
}
