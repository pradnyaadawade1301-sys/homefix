package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type ConsultationRepository struct {
	db *pgxpool.Pool
}

func NewConsultationRepository(database *pgxpool.Pool) *ConsultationRepository {
	return &ConsultationRepository{db: database}
}

// Create makes a new consultation. If scheduledAt is nil, it's the existing
// instant flow (status 'searching', ready to be rung right away). If scheduledAt
// is set, it starts life as 'scheduled' — nobody is rung yet.
func (r *ConsultationRepository) Create(ctx context.Context, customerID, categoryID string, fee float64, scheduledAt *time.Time) (*models.Consultation, error) {
	status := "searching"
	if scheduledAt != nil {
		status = "scheduled"
	}
	row := r.db.QueryRow(ctx, `
		INSERT INTO consultations (customer_id, category_id, fee, status, scheduled_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, customer_id, technician_id, category_id, status, fee, duration_seconds,
		          payment_status, escalated_booking_id, decline_reason,
		          recommendation_summary, recommendation_price, recommendation_status, recommendation_sent_at,
		          scheduled_at, started_at, ended_at, created_at, updated_at
	`, customerID, categoryID, fee, status, scheduledAt)
	return scanConsultation(row)
}

func (r *ConsultationRepository) GetByID(ctx context.Context, id string) (*models.Consultation, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, customer_id, technician_id, category_id, status, fee, duration_seconds,
		       payment_status, escalated_booking_id, decline_reason,
		       recommendation_summary, recommendation_price, recommendation_status, recommendation_sent_at,
		       scheduled_at, started_at, ended_at, created_at, updated_at
		FROM consultations WHERE id = $1
	`, id)
	c, err := scanConsultation(row)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return c, err
}

// GetWithDetails is what the customer polls while the screen shows "Searching...",
// "Ringing...", etc. — it carries the matched technician's name/phone once assigned.
func (r *ConsultationRepository) GetWithDetails(ctx context.Context, id string) (*models.ConsultationWithDetails, error) {
	row := r.db.QueryRow(ctx, `
		SELECT co.id, co.customer_id, co.technician_id, co.category_id, co.status, co.fee,
		       co.duration_seconds, co.payment_status, co.escalated_booking_id, co.decline_reason,
		       co.recommendation_summary, co.recommendation_price, co.recommendation_status, co.recommendation_sent_at,
		       co.scheduled_at, co.started_at, co.ended_at, co.created_at, co.updated_at,
		       COALESCE(cat.name, ''), COALESCE(cu.name, ''), COALESCE(cu.phone, ''),
		       COALESCE(tu.name, ''), COALESCE(tu.phone, '')
		FROM consultations co
		LEFT JOIN categories cat ON cat.id = co.category_id
		LEFT JOIN users cu ON cu.id = co.customer_id
		LEFT JOIN technicians t ON t.id = co.technician_id
		LEFT JOIN users tu ON tu.id = t.user_id
		WHERE co.id = $1
	`, id)

	var d models.ConsultationWithDetails
	err := row.Scan(
		&d.ID, &d.CustomerID, &d.TechnicianID, &d.CategoryID, &d.Status, &d.Fee,
		&d.DurationSeconds, &d.PaymentStatus, &d.EscalatedBookingID, &d.DeclineReason,
		&d.RecommendationSummary, &d.RecommendationPrice, &d.RecommendationStatus, &d.RecommendationSentAt,
		&d.ScheduledAt, &d.StartedAt, &d.EndedAt, &d.CreatedAt, &d.UpdatedAt,
		&d.CategoryName, &d.CustomerName, &d.CustomerPhone, &d.TechnicianName, &d.TechnicianPhone,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// AssignTechnician moves an INSTANT consultation from "searching" to "ringing" for a
// specific technician — this is what makes the incoming-request card show up on
// their side immediately.
func (r *ConsultationRepository) AssignTechnician(ctx context.Context, id, technicianID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET technician_id = $2, status = 'ringing', updated_at = now()
		WHERE id = $1
	`, id, technicianID)
	return err
}

// AssignTechnicianScheduled moves a SCHEDULED consultation from "scheduled" to
// "confirmed" once a technician is matched — they are NOT rung yet, just asked to
// hold that slot. The actual ring happens later via PromoteToRinging.
func (r *ConsultationRepository) AssignTechnicianScheduled(ctx context.Context, id, technicianID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET technician_id = $2, status = 'confirmed', updated_at = now()
		WHERE id = $1
	`, id, technicianID)
	return err
}

func (r *ConsultationRepository) UpdateStatus(ctx context.Context, id, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE consultations SET status = $2, updated_at = now() WHERE id = $1`, id, status)
	return err
}

// UpdateStatusWithReason is UpdateStatus plus a reason string — used when a
// technician declines a scheduled slot (or rejects an instant request) and
// explains why, so the customer isn't left with a bare "declined" and nothing
// else. Pass "" for statuses that don't need a reason.
func (r *ConsultationRepository) UpdateStatusWithReason(ctx context.Context, id, status, reason string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET status = $2, decline_reason = NULLIF($3, ''), updated_at = now()
		WHERE id = $1
	`, id, status, reason)
	return err
}

// UnassignForRetry clears the current technician and puts the consultation back into
// "searching" — used when a technician rejects, so the backend can try the next
// nearest one instead of dead-ending the customer's request.
func (r *ConsultationRepository) UnassignForRetry(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET technician_id = NULL, status = 'searching', updated_at = now()
		WHERE id = $1
	`, id)
	return err
}

func (r *ConsultationRepository) MarkStarted(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET status = 'in_call', started_at = now(), updated_at = now()
		WHERE id = $1
	`, id)
	return err
}

func (r *ConsultationRepository) MarkEnded(ctx context.Context, id string, durationSeconds int) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations
		SET status = 'ended', ended_at = now(), duration_seconds = $2, updated_at = now()
		WHERE id = $1
	`, id, durationSeconds)
	return err
}

func (r *ConsultationRepository) SetPaymentStatus(ctx context.Context, id, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE consultations SET payment_status = $2, updated_at = now() WHERE id = $1`, id, status)
	return err
}

func (r *ConsultationRepository) SetEscalatedBooking(ctx context.Context, id, bookingID string) error {
	_, err := r.db.Exec(ctx, `UPDATE consultations SET escalated_booking_id = $2, updated_at = now() WHERE id = $1`, id, bookingID)
	return err
}

// SetRecommendation stores the technician's post-call "here's what I found and
// what it'll cost" note and flips recommendation_status to "pending" so the
// customer sees an Accept/Decline prompt. sentAt is set to now() here rather
// than left to the caller so it always reflects when the DB write actually
// happened.
func (r *ConsultationRepository) SetRecommendation(ctx context.Context, id, summary string, price *float64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations
		SET recommendation_summary = $2, recommendation_price = $3, recommendation_status = 'pending',
		    recommendation_sent_at = now(), updated_at = now()
		WHERE id = $1
	`, id, summary, price)
	return err
}

// UpdateRecommendationStatus moves a pending recommendation to "accepted" (see
// ConsultationService.Escalate) or "declined" (see DeclineRecommendation).
func (r *ConsultationRepository) UpdateRecommendationStatus(ctx context.Context, id, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE consultations SET recommendation_status = $2, updated_at = now() WHERE id = $1`, id, status)
	return err
}

// Cancel is the customer giving up while still searching/ringing/scheduled/confirmed
// for a technician. Once a technician has accepted (or later), the customer must end
// the call properly instead of silently cancelling it.
func (r *ConsultationRepository) Cancel(ctx context.Context, id, customerID string) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE consultations SET status = 'cancelled', updated_at = now()
		WHERE id = $1 AND customer_id = $2 AND status IN ('searching', 'ringing', 'scheduled', 'confirmed')
	`, id, customerID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// ListPendingForTechnician returns the incoming-request queue for a technician: any
// consultation currently ringing them RIGHT NOW (instant flow, or a scheduled one
// whose slot just arrived — both end up in 'ringing').
func (r *ConsultationRepository) ListPendingForTechnician(ctx context.Context, technicianID string) ([]models.ConsultationWithDetails, error) {
	return r.listForTechnicianByStatus(ctx, technicianID, "ringing")
}

// ListUpcomingForTechnician returns scheduled consultations awaiting the
// technician's confirmation ('scheduled') or already confirmed and waiting for
// their slot ('confirmed') — this powers an "Upcoming Consultations" list separate
// from the urgent incoming-request card.
func (r *ConsultationRepository) ListUpcomingForTechnician(ctx context.Context, technicianID string) ([]models.ConsultationWithDetails, error) {
	rows, err := r.db.Query(ctx, `
		SELECT co.id, co.customer_id, co.technician_id, co.category_id, co.status, co.fee,
		       co.duration_seconds, co.payment_status, co.escalated_booking_id, co.decline_reason,
		       co.recommendation_summary, co.recommendation_price, co.recommendation_status, co.recommendation_sent_at,
		       co.scheduled_at, co.started_at, co.ended_at, co.created_at, co.updated_at,
		       COALESCE(cat.name, ''), COALESCE(cu.name, ''), COALESCE(cu.phone, ''), '', ''
		FROM consultations co
		LEFT JOIN categories cat ON cat.id = co.category_id
		LEFT JOIN users cu ON cu.id = co.customer_id
		WHERE co.technician_id = $1 AND co.status IN ('scheduled', 'confirmed')
		ORDER BY co.scheduled_at ASC NULLS LAST
	`, technicianID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanConsultationRows(rows)
}

// DueForRinging finds every 'confirmed' scheduled consultation whose slot time has
// arrived (scheduled_at <= now) — polled periodically (see
// ConsultationService.PromoteDueScheduled) to flip them into 'ringing' and notify
// both sides, without either app needing to be open at that exact moment.
func (r *ConsultationRepository) DueForRinging(ctx context.Context) ([]models.Consultation, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, customer_id, technician_id, category_id, status, fee, duration_seconds,
		       payment_status, escalated_booking_id, decline_reason, scheduled_at, started_at, ended_at, created_at, updated_at
		FROM consultations
		WHERE status = 'confirmed' AND scheduled_at IS NOT NULL AND scheduled_at <= now()
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Consultation
	for rows.Next() {
		var c models.Consultation
		if err := rows.Scan(
			&c.ID, &c.CustomerID, &c.TechnicianID, &c.CategoryID, &c.Status, &c.Fee,
			&c.DurationSeconds, &c.PaymentStatus, &c.EscalatedBookingID, &c.DeclineReason,
			&c.ScheduledAt, &c.StartedAt, &c.EndedAt, &c.CreatedAt, &c.UpdatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, nil
}

// PromoteToRinging flips a due 'confirmed' scheduled consultation to 'ringing' —
// same terminal state the instant flow's AssignTechnician produces, so every
// downstream screen (incoming request card, accept/reject, call connect) works
// identically regardless of which flow got it there.
func (r *ConsultationRepository) PromoteToRinging(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET status = 'ringing', updated_at = now()
		WHERE id = $1 AND status = 'confirmed'
	`, id)
	return err
}

// ListForCustomer returns every consultation the customer has ever started, most
// recent first — powers the "My Consultations" / call-history screen (GET
// /consultations/mine). Unlike ListPendingForTechnician this is NOT filtered by
// status: the history screen itself splits into upcoming/completed/cancelled tabs.
func (r *ConsultationRepository) ListForCustomer(ctx context.Context, customerID string) ([]models.ConsultationWithDetails, error) {
	rows, err := r.db.Query(ctx, `
		SELECT co.id, co.customer_id, co.technician_id, co.category_id, co.status, co.fee,
		       co.duration_seconds, co.payment_status, co.escalated_booking_id, co.decline_reason,
		       co.recommendation_summary, co.recommendation_price, co.recommendation_status, co.recommendation_sent_at,
		       co.scheduled_at, co.started_at, co.ended_at, co.created_at, co.updated_at,
		       COALESCE(cat.name, ''), COALESCE(cu.name, ''), COALESCE(cu.phone, ''),
		       COALESCE(tu.name, ''), COALESCE(tu.phone, '')
		FROM consultations co
		LEFT JOIN categories cat ON cat.id = co.category_id
		LEFT JOIN users cu ON cu.id = co.customer_id
		LEFT JOIN technicians t ON t.id = co.technician_id
		LEFT JOIN users tu ON tu.id = t.user_id
		WHERE co.customer_id = $1
		ORDER BY co.created_at DESC
	`, customerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanConsultationRows(rows)
}

// MarkEndedWithStats is MarkEnded plus the client-reported session-analytics fields
// gathered during the call (see RtcService in the app: reconnect attempts and a
// coarse connection-quality sample from getStats()).
func (r *ConsultationRepository) MarkEndedWithStats(ctx context.Context, id string, durationSeconds, reconnectCount int, connectionQuality string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations
		SET status = 'ended', ended_at = now(), duration_seconds = $2,
		    reconnect_count = $3, connection_quality = NULLIF($4, ''), updated_at = now()
		WHERE id = $1
	`, id, durationSeconds, reconnectCount, connectionQuality)
	return err
}

// SetRating stores the customer's rating for a consultation that never became a
// booking (see ReviewRepository.CreateForConsultation for the technician-rating-avg
// side effect — same trigger booking reviews use).
func (r *ConsultationRepository) SetRating(ctx context.Context, id string, rating int, comment string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET rating = $2, rating_comment = NULLIF($3, ''), updated_at = now()
		WHERE id = $1
	`, id, rating, comment)
	return err
}

func (r *ConsultationRepository) listForTechnicianByStatus(ctx context.Context, technicianID, status string) ([]models.ConsultationWithDetails, error) {
	rows, err := r.db.Query(ctx, `
		SELECT co.id, co.customer_id, co.technician_id, co.category_id, co.status, co.fee,
		       co.duration_seconds, co.payment_status, co.escalated_booking_id, co.decline_reason,
		       co.recommendation_summary, co.recommendation_price, co.recommendation_status, co.recommendation_sent_at,
		       co.scheduled_at, co.started_at, co.ended_at, co.created_at, co.updated_at,
		       COALESCE(cat.name, ''), COALESCE(cu.name, ''), COALESCE(cu.phone, ''), '', ''
		FROM consultations co
		LEFT JOIN categories cat ON cat.id = co.category_id
		LEFT JOIN users cu ON cu.id = co.customer_id
		WHERE co.technician_id = $1 AND co.status = $2
		ORDER BY co.created_at ASC
	`, technicianID, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanConsultationRows(rows)
}

func scanConsultationRows(rows pgx.Rows) ([]models.ConsultationWithDetails, error) {
	var out []models.ConsultationWithDetails
	for rows.Next() {
		var d models.ConsultationWithDetails
		if err := rows.Scan(
			&d.ID, &d.CustomerID, &d.TechnicianID, &d.CategoryID, &d.Status, &d.Fee,
			&d.DurationSeconds, &d.PaymentStatus, &d.EscalatedBookingID, &d.DeclineReason,
			&d.RecommendationSummary, &d.RecommendationPrice, &d.RecommendationStatus, &d.RecommendationSentAt,
			&d.ScheduledAt, &d.StartedAt, &d.EndedAt, &d.CreatedAt, &d.UpdatedAt,
			&d.CategoryName, &d.CustomerName, &d.CustomerPhone, &d.TechnicianName, &d.TechnicianPhone,
		); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, nil
}

func scanConsultation(row pgx.Row) (*models.Consultation, error) {
	var c models.Consultation
	err := row.Scan(
		&c.ID, &c.CustomerID, &c.TechnicianID, &c.CategoryID, &c.Status, &c.Fee,
		&c.DurationSeconds, &c.PaymentStatus, &c.EscalatedBookingID, &c.DeclineReason,
		&c.RecommendationSummary, &c.RecommendationPrice, &c.RecommendationStatus, &c.RecommendationSentAt,
		&c.ScheduledAt, &c.StartedAt, &c.EndedAt, &c.CreatedAt, &c.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &c, nil
}