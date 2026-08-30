package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type ReviewRepository struct {
	db *pgxpool.Pool
}

func NewReviewRepository(db *pgxpool.Pool) *ReviewRepository {
	return &ReviewRepository{db: db}
}

// Create relies on the DB trigger (trg_update_technician_rating) to update technician rating_avg atomically.
func (r *ReviewRepository) Create(ctx context.Context, rv *models.Review) (*models.Review, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO reviews (booking_id, customer_id, technician_id, rating, comment)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, created_at
	`, rv.BookingID, rv.CustomerID, rv.TechnicianID, rv.Rating, rv.Comment).Scan(&rv.ID, &rv.CreatedAt)
	if err != nil {
		return nil, err
	}
	return rv, nil
}

// CreateForConsultation records a rating for a live consultation that resolved the
// issue remotely (no home-visit booking involved) — same technician-rating-avg
// trigger as a booking review, just keyed off consultation_id instead of booking_id.
func (r *ReviewRepository) CreateForConsultation(ctx context.Context, consultationID, customerID, technicianID string, rating int, comment string) (*models.Review, error) {
	rv := &models.Review{
		CustomerID:   customerID,
		TechnicianID: technicianID,
		Rating:       rating,
		Comment:      comment,
	}
	err := r.db.QueryRow(ctx, `
		INSERT INTO reviews (consultation_id, customer_id, technician_id, rating, comment)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, created_at
	`, consultationID, customerID, technicianID, rating, comment).Scan(&rv.ID, &rv.CreatedAt)
	if err != nil {
		return nil, err
	}
	return rv, nil
}

func (r *ReviewRepository) ListByTechnician(ctx context.Context, technicianID string) ([]models.Review, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, booking_id, customer_id, technician_id, rating, COALESCE(comment,''), created_at
		FROM reviews WHERE technician_id = $1 ORDER BY created_at DESC
	`, technicianID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Review
	for rows.Next() {
		var rv models.Review
		if err := rows.Scan(&rv.ID, &rv.BookingID, &rv.CustomerID, &rv.TechnicianID, &rv.Rating, &rv.Comment, &rv.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, rv)
	}
	return out, nil
}
