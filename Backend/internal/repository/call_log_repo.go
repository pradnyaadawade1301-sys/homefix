package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type CallLogRepository struct {
	db *pgxpool.Pool
}

func NewCallLogRepository(database *pgxpool.Pool) *CallLogRepository {
	return &CallLogRepository{db: database}
}

// Create writes a new 'ringing' row the moment a call is initiated — this is
// what makes the call show up in history even if it's never answered
// (a missed call still needs its own row).
func (r *CallLogRepository) Create(ctx context.Context, bookingID, consultationID *string, callerUserID, calleeUserID string) (*models.CallLog, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO call_logs (booking_id, consultation_id, caller_user_id, callee_user_id, status)
		VALUES ($1, $2, $3, $4, 'ringing')
		RETURNING id, booking_id, consultation_id, caller_user_id, callee_user_id, status,
		          started_at, answered_at, ended_at, duration_seconds, created_at
	`, bookingID, consultationID, callerUserID, calleeUserID)
	return scanCallLog(row)
}

// MarkAnswered flips the most recent still-ringing log for a thread (booking
// or consultation id) to 'received' the moment both sides are actually in
// the call room together (see CallHandler.join — this fires when a room
// reaches 2 participants).
func (r *CallLogRepository) MarkAnswered(ctx context.Context, threadID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE call_logs
		SET status = 'received', answered_at = now()
		WHERE id = (
			SELECT id FROM call_logs
			WHERE (booking_id = $1 OR consultation_id = $1) AND status = 'ringing'
			ORDER BY created_at DESC LIMIT 1
		)
	`, threadID)
	return err
}

// MarkEnded closes out the most recent open log for a thread once the call
// room empties. If it was never answered, it settles as 'missed'; if it was
// answered, it becomes a completed 'received' call with a duration.
func (r *CallLogRepository) MarkEnded(ctx context.Context, threadID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE call_logs
		SET status = CASE WHEN answered_at IS NULL THEN 'missed' ELSE status END,
		    ended_at = now(),
		    duration_seconds = CASE WHEN answered_at IS NOT NULL THEN EXTRACT(EPOCH FROM (now() - answered_at))::int ELSE NULL END
		WHERE id = (
			SELECT id FROM call_logs
			WHERE (booking_id = $1 OR consultation_id = $1) AND ended_at IS NULL
			ORDER BY created_at DESC LIMIT 1
		)
	`, threadID)
	return err
}

// ListForUser returns every call (as caller or callee) a user has ever been
// part of, most recent first, joined with the other participant's name/role
// so the app can render a WhatsApp/phone-style call log directly.
func (r *CallLogRepository) ListForUser(ctx context.Context, userID string, limit int) ([]models.CallLogEntry, error) {
	if limit <= 0 {
		limit = 100
	}
	rows, err := r.db.Query(ctx, `
		SELECT cl.id, cl.booking_id, cl.consultation_id, cl.caller_user_id, cl.callee_user_id,
		       cl.status, cl.started_at, cl.answered_at, cl.ended_at, cl.duration_seconds, cl.created_at,
		       peer.name, peer.role,
		       COALESCE(cat.name, '') AS category_name
		FROM call_logs cl
		JOIN users peer ON peer.id = (CASE WHEN cl.caller_user_id = $1 THEN cl.callee_user_id ELSE cl.caller_user_id END)
		LEFT JOIN bookings b ON b.id = cl.booking_id
		LEFT JOIN consultations co ON co.id = cl.consultation_id
		LEFT JOIN categories cat ON cat.id = COALESCE(b.category_id, co.category_id)
		WHERE cl.caller_user_id = $1 OR cl.callee_user_id = $1
		ORDER BY cl.created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.CallLogEntry
	for rows.Next() {
		var e models.CallLogEntry
		if err := rows.Scan(
			&e.ID, &e.BookingID, &e.ConsultationID, &e.CallerUserID, &e.CalleeUserID,
			&e.Status, &e.StartedAt, &e.AnsweredAt, &e.EndedAt, &e.DurationSeconds, &e.CreatedAt,
			&e.PeerName, &e.PeerRole, &e.CategoryName,
		); err != nil {
			return nil, err
		}
		e.IsOutgoing = e.CallerUserID == userID
		out = append(out, e)
	}
	return out, rows.Err()
}

func scanCallLog(row pgx.Row) (*models.CallLog, error) {
	var c models.CallLog
	var startedAt time.Time
	if err := row.Scan(
		&c.ID, &c.BookingID, &c.ConsultationID, &c.CallerUserID, &c.CalleeUserID,
		&c.Status, &startedAt, &c.AnsweredAt, &c.EndedAt, &c.DurationSeconds, &c.CreatedAt,
	); err != nil {
		return nil, err
	}
	c.StartedAt = startedAt
	return &c, nil
}