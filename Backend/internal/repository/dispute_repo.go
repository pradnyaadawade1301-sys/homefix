package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type DisputeRepository struct {
	db *pgxpool.Pool
}

func NewDisputeRepository(db *pgxpool.Pool) *DisputeRepository {
	return &DisputeRepository{db: db}
}

const disputeColumns = `d.id, d.booking_id, d.consultation_id, d.raised_by, d.reason, d.status,
	       d.refund_amount, d.admin_notes, d.resolved_by, d.resolved_at, d.created_at, d.updated_at,
	       COALESCE(u.name, '')`

func scanDispute(row pgx.Row) (*models.Dispute, error) {
	var d models.Dispute
	err := row.Scan(&d.ID, &d.BookingID, &d.ConsultationID, &d.RaisedBy, &d.Reason, &d.Status,
		&d.RefundAmount, &d.AdminNotes, &d.ResolvedBy, &d.ResolvedAt, &d.CreatedAt, &d.UpdatedAt,
		&d.RaisedByName)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

func (r *DisputeRepository) Create(ctx context.Context, d *models.Dispute) (*models.Dispute, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO disputes (booking_id, consultation_id, raised_by, reason)
		VALUES ($1,$2,$3,$4)
		RETURNING id, status, created_at, updated_at
	`, d.BookingID, d.ConsultationID, d.RaisedBy, d.Reason).Scan(&d.ID, &d.Status, &d.CreatedAt, &d.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return d, nil
}

func (r *DisputeRepository) AddEvidence(ctx context.Context, e *models.DisputeEvidence) (*models.DisputeEvidence, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO dispute_evidence (dispute_id, uploaded_by, file_url, note)
		VALUES ($1,$2,$3,$4)
		RETURNING id, created_at
	`, e.DisputeID, e.UploadedBy, e.FileURL, e.Note).Scan(&e.ID, &e.CreatedAt)
	if err != nil {
		return nil, err
	}
	return e, nil
}

func (r *DisputeRepository) ListEvidence(ctx context.Context, disputeID string) ([]models.DisputeEvidence, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, dispute_id, uploaded_by, file_url, COALESCE(note,''), created_at
		FROM dispute_evidence WHERE dispute_id = $1 ORDER BY created_at ASC
	`, disputeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.DisputeEvidence
	for rows.Next() {
		var e models.DisputeEvidence
		if err := rows.Scan(&e.ID, &e.DisputeID, &e.UploadedBy, &e.FileURL, &e.Note, &e.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *DisputeRepository) GetByID(ctx context.Context, id string) (*models.Dispute, error) {
	d, err := scanDispute(r.db.QueryRow(ctx, `
		SELECT `+disputeColumns+` FROM disputes d JOIN users u ON u.id = d.raised_by WHERE d.id = $1
	`, id))
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return d, err
}

func (r *DisputeRepository) ListByUser(ctx context.Context, userID string) ([]models.Dispute, error) {
	return r.list(ctx, "d.raised_by = $1", userID)
}

// ListAll powers the admin panel's dispute queue; status="" lists every status.
func (r *DisputeRepository) ListAll(ctx context.Context, status string) ([]models.Dispute, error) {
	if status == "" {
		return r.list(ctx, "TRUE")
	}
	return r.list(ctx, "d.status = $1", status)
}

func (r *DisputeRepository) list(ctx context.Context, where string, args ...interface{}) ([]models.Dispute, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+disputeColumns+`
		FROM disputes d JOIN users u ON u.id = d.raised_by
		WHERE `+where+` ORDER BY d.created_at DESC
	`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Dispute
	for rows.Next() {
		d, err := scanDispute(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *d)
	}
	return out, rows.Err()
}

func (r *DisputeRepository) SetUnderReview(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, `UPDATE disputes SET status = 'under_review', updated_at = now() WHERE id = $1 AND status = 'open'`, id)
	return err
}

func (r *DisputeRepository) Resolve(ctx context.Context, id, status, adminNotes, resolvedBy string, refundAmount *float64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE disputes
		SET status = $2, admin_notes = NULLIF($3, ''), refund_amount = $4,
		    resolved_by = $5, resolved_at = now(), updated_at = now()
		WHERE id = $1
	`, id, status, adminNotes, refundAmount, resolvedBy)
	return err
}

func (r *DisputeRepository) CountOpen(ctx context.Context) (int, error) {
	var n int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM disputes WHERE status IN ('open','under_review')`).Scan(&n)
	return n, err
}
