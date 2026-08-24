package repository

import (
	"context"

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

func (r *ConsultationRepository) Create(ctx context.Context, customerID, categoryID string, fee float64) (*models.Consultation, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO consultations (customer_id, category_id, fee, status)
		VALUES ($1, $2, $3, 'searching')
		RETURNING id, customer_id, technician_id, category_id, status, fee, duration_seconds,
		          payment_status, escalated_booking_id, started_at, ended_at, created_at, updated_at
	`, customerID, categoryID, fee)
	return scanConsultation(row)
}

func (r *ConsultationRepository) GetByID(ctx context.Context, id string) (*models.Consultation, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, customer_id, technician_id, category_id, status, fee, duration_seconds,
		       payment_status, escalated_booking_id, started_at, ended_at, created_at, updated_at
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
		       co.duration_seconds, co.payment_status, co.escalated_booking_id, co.started_at,
		       co.ended_at, co.created_at, co.updated_at,
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
		&d.DurationSeconds, &d.PaymentStatus, &d.EscalatedBookingID, &d.StartedAt,
		&d.EndedAt, &d.CreatedAt, &d.UpdatedAt,
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

// AssignTechnician moves a consultation from "searching" to "ringing" for a specific
// technician — this is what makes the incoming-request card show up on their side.
func (r *ConsultationRepository) AssignTechnician(ctx context.Context, id, technicianID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE consultations SET technician_id = $2, status = 'ringing', updated_at = now()
		WHERE id = $1
	`, id, technicianID)
	return err
}

func (r *ConsultationRepository) UpdateStatus(ctx context.Context, id, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE consultations SET status = $2, updated_at = now() WHERE id = $1`, id, status)
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

// Cancel is the customer giving up while still searching/ringing for a technician.
// Only allowed in those two states — once a technician has accepted (or later), the
// customer must end the call properly instead of silently cancelling it.
func (r *ConsultationRepository) Cancel(ctx context.Context, id, customerID string) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE consultations SET status = 'cancelled', updated_at = now()
		WHERE id = $1 AND customer_id = $2 AND status IN ('searching', 'ringing')
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
// consultation currently ringing them. Same room used for the video call once
// accepted, so this is also what repopulates the Incoming Request screen if it's
// opened directly instead of via the FCM push.
func (r *ConsultationRepository) ListPendingForTechnician(ctx context.Context, technicianID string) ([]models.ConsultationWithDetails, error) {
	rows, err := r.db.Query(ctx, `
		SELECT co.id, co.customer_id, co.technician_id, co.category_id, co.status, co.fee,
		       co.duration_seconds, co.payment_status, co.escalated_booking_id, co.started_at,
		       co.ended_at, co.created_at, co.updated_at,
		       COALESCE(cat.name, ''), COALESCE(cu.name, ''), COALESCE(cu.phone, ''), '', ''
		FROM consultations co
		LEFT JOIN categories cat ON cat.id = co.category_id
		LEFT JOIN users cu ON cu.id = co.customer_id
		WHERE co.technician_id = $1 AND co.status = 'ringing'
		ORDER BY co.created_at ASC
	`, technicianID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.ConsultationWithDetails
	for rows.Next() {
		var d models.ConsultationWithDetails
		if err := rows.Scan(
			&d.ID, &d.CustomerID, &d.TechnicianID, &d.CategoryID, &d.Status, &d.Fee,
			&d.DurationSeconds, &d.PaymentStatus, &d.EscalatedBookingID, &d.StartedAt,
			&d.EndedAt, &d.CreatedAt, &d.UpdatedAt,
			&d.CategoryName, &d.CustomerName, &d.CustomerPhone, &d.TechnicianName, &d.TechnicianPhone,
		); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, nil
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

func scanConsultation(row pgx.Row) (*models.Consultation, error) {
	var c models.Consultation
	err := row.Scan(
		&c.ID, &c.CustomerID, &c.TechnicianID, &c.CategoryID, &c.Status, &c.Fee,
		&c.DurationSeconds, &c.PaymentStatus, &c.EscalatedBookingID, &c.StartedAt,
		&c.EndedAt, &c.CreatedAt, &c.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &c, nil
}
