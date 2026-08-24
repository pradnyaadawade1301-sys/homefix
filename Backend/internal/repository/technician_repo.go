package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type TechnicianRepository struct {
	db *pgxpool.Pool
}

func NewTechnicianRepository(db *pgxpool.Pool) *TechnicianRepository {
	return &TechnicianRepository{db: db}
}

func (r *TechnicianRepository) Create(ctx context.Context, t *models.Technician) (*models.Technician, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO technicians (user_id, category_id, experience_years, address, government_id_url,
		                          profile_photo_url, approval_status, is_verified, is_available)
		VALUES ($1,$2,$3,$4,$5,$6,'pending',false,true)
		RETURNING id, approval_status, rating_avg, rating_count, is_verified, is_available, created_at, updated_at
	`, t.UserID, t.CategoryID, t.ExperienceYears, t.Address, t.GovernmentIDURL, t.ProfilePhotoURL).Scan(
		&t.ID, &t.ApprovalStatus, &t.RatingAvg, &t.RatingCount, &t.IsVerified, &t.IsAvailable, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return t, nil
}

const technicianColumns = `id, user_id, category_id, experience_years, COALESCE(address,''),
	COALESCE(government_id_url,''), COALESCE(profile_photo_url,''), approval_status,
	COALESCE(rejection_reason,''), rating_avg, rating_count, is_verified, is_available,
	current_lat, current_lng, created_at, updated_at`

func scanTechnician(row pgx.Row, t *models.Technician) error {
	return row.Scan(&t.ID, &t.UserID, &t.CategoryID, &t.ExperienceYears, &t.Address, &t.GovernmentIDURL,
		&t.ProfilePhotoURL, &t.ApprovalStatus, &t.RejectionReason, &t.RatingAvg, &t.RatingCount,
		&t.IsVerified, &t.IsAvailable, &t.CurrentLat, &t.CurrentLng, &t.CreatedAt, &t.UpdatedAt)
}

func (r *TechnicianRepository) GetByID(ctx context.Context, id string) (*models.Technician, error) {
	var t models.Technician
	err := scanTechnician(r.db.QueryRow(ctx, `SELECT `+technicianColumns+` FROM technicians WHERE id = $1`, id), &t)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &t, nil
}

func (r *TechnicianRepository) GetByUserID(ctx context.Context, userID string) (*models.Technician, error) {
	var t models.Technician
	err := scanTechnician(r.db.QueryRow(ctx, `SELECT `+technicianColumns+` FROM technicians WHERE user_id = $1`, userID), &t)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &t, nil
}

// ListAvailableByCategory finds available, verified technicians for a category, joined
// with the technician's name and category name (the raw table alone isn't enough for the
// nearby/tracking UI — it needs a name to show and a distance to sort/display by).
// Nearest-first when coordinates are supplied, using the haversine formula for a real
// distance in km rather than a raw squared-degree ordering; falls back to rating-first
// when no coordinates are given.
func (r *TechnicianRepository) ListAvailableByCategory(ctx context.Context, categoryID string, lat, lng *float64) ([]models.TechnicianNearby, error) {
	var rows pgx.Rows
	var err error
	if lat != nil && lng != nil {
		rows, err = r.db.Query(ctx, `
			SELECT t.id, COALESCE(u.name,''), t.category_id, c.name, t.experience_years,
			       t.rating_avg, t.rating_count, t.is_available, t.current_lat, t.current_lng,
			       (6371 * acos(LEAST(1.0, GREATEST(-1.0,
			           cos(radians($2)) * cos(radians(COALESCE(t.current_lat,$2))) *
			           cos(radians(COALESCE(t.current_lng,$3)) - radians($3)) +
			           sin(radians($2)) * sin(radians(COALESCE(t.current_lat,$2)))
			       )))) AS distance_km
			FROM technicians t
			JOIN users u ON u.id = t.user_id
			JOIN categories c ON c.id = t.category_id
			WHERE t.category_id = $1 AND t.is_available = true AND t.approval_status = 'approved'
			ORDER BY distance_km ASC
			LIMIT 20
		`, categoryID, *lat, *lng)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT t.id, COALESCE(u.name,''), t.category_id, c.name, t.experience_years,
			       t.rating_avg, t.rating_count, t.is_available, t.current_lat, t.current_lng,
			       NULL::float8 AS distance_km
			FROM technicians t
			JOIN users u ON u.id = t.user_id
			JOIN categories c ON c.id = t.category_id
			WHERE t.category_id = $1 AND t.is_available = true AND t.approval_status = 'approved'
			ORDER BY t.rating_avg DESC
			LIMIT 20
		`, categoryID)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.TechnicianNearby
	for rows.Next() {
		var t models.TechnicianNearby
		if err := rows.Scan(&t.ID, &t.Name, &t.CategoryID, &t.CategoryName, &t.ExperienceYears,
			&t.RatingAvg, &t.RatingCount, &t.IsAvailable, &t.CurrentLat, &t.CurrentLng, &t.DistanceKm); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, nil
}

// ListPublic returns verified technicians (optionally filtered by category) joined with
// their name and category name, for the public "browse technicians" screen. No auth required.
func (r *TechnicianRepository) ListPublic(ctx context.Context, categoryID string) ([]models.TechnicianPublic, error) {
	query := `
		SELECT t.id, COALESCE(u.name,''), t.category_id, c.name, t.experience_years,
		       t.rating_avg, t.rating_count, t.is_verified, t.is_available, t.created_at
		FROM technicians t
		JOIN users u ON u.id = t.user_id
		JOIN categories c ON c.id = t.category_id
		WHERE t.is_verified = true`
	args := []interface{}{}
	if categoryID != "" {
		query += " AND t.category_id = $1"
		args = append(args, categoryID)
	}
	query += " ORDER BY t.rating_avg DESC LIMIT 50"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.TechnicianPublic
	for rows.Next() {
		var t models.TechnicianPublic
		if err := rows.Scan(&t.ID, &t.Name, &t.CategoryID, &t.CategoryName, &t.ExperienceYears,
			&t.RatingAvg, &t.RatingCount, &t.IsVerified, &t.IsAvailable, &t.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, nil
}

// GetPublicByID returns a single technician's public profile, joined with name + category.
func (r *TechnicianRepository) GetPublicByID(ctx context.Context, id string) (*models.TechnicianPublic, error) {
	var t models.TechnicianPublic
	err := r.db.QueryRow(ctx, `
		SELECT t.id, COALESCE(u.name,''), t.category_id, c.name, t.experience_years,
		       t.rating_avg, t.rating_count, t.is_verified, t.is_available, t.created_at
		FROM technicians t
		JOIN users u ON u.id = t.user_id
		JOIN categories c ON c.id = t.category_id
		WHERE t.id = $1
	`, id).Scan(&t.ID, &t.Name, &t.CategoryID, &t.CategoryName, &t.ExperienceYears,
		&t.RatingAvg, &t.RatingCount, &t.IsVerified, &t.IsAvailable, &t.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &t, nil
}

func (r *TechnicianRepository) SetAvailability(ctx context.Context, id string, available bool) error {
	_, err := r.db.Exec(ctx, `UPDATE technicians SET is_available = $1, updated_at = now() WHERE id = $2`, available, id)
	return err
}

func (r *TechnicianRepository) UpdateLocation(ctx context.Context, id string, lat, lng float64) error {
	_, err := r.db.Exec(ctx, `UPDATE technicians SET current_lat = $1, current_lng = $2, updated_at = now() WHERE id = $3`,
		lat, lng, id)
	return err
}

// ListByApprovalStatus powers the admin panel's Technician Approval queue.
// status == "" lists every technician regardless of approval state.
func (r *TechnicianRepository) ListByApprovalStatus(ctx context.Context, status string) ([]models.TechnicianWithUser, error) {
	query := `
		SELECT t.id, t.user_id, COALESCE(u.name,''), u.phone, t.category_id, COALESCE(c.name,''),
		       t.experience_years, COALESCE(t.address,''), COALESCE(t.government_id_url,''),
		       COALESCE(t.profile_photo_url,''), t.approval_status, COALESCE(t.rejection_reason,''),
		       t.rating_avg, t.rating_count, t.is_verified, t.is_available, t.created_at
		FROM technicians t
		JOIN users u ON u.id = t.user_id
		JOIN categories c ON c.id = t.category_id`
	args := []interface{}{}
	if status != "" {
		query += ` WHERE t.approval_status = $1`
		args = append(args, status)
	}
	query += ` ORDER BY t.created_at DESC`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.TechnicianWithUser
	for rows.Next() {
		var t models.TechnicianWithUser
		if err := rows.Scan(&t.ID, &t.UserID, &t.Name, &t.Phone, &t.CategoryID, &t.CategoryName,
			&t.ExperienceYears, &t.Address, &t.GovernmentIDURL, &t.ProfilePhotoURL, &t.ApprovalStatus,
			&t.RejectionReason, &t.RatingAvg, &t.RatingCount, &t.IsVerified, &t.IsAvailable, &t.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// SetApprovalStatus is how an admin approves or rejects a technician's KYC submission.
// status must be "approved" or "rejected"; is_verified is kept in sync so existing
// browse/booking queries (which filter on is_verified) keep working unchanged.
func (r *TechnicianRepository) SetApprovalStatus(ctx context.Context, id, status, reason string) error {
	// $1 is used both as the varchar assigned to approval_status and inside a
	// boolean comparison for is_verified — pgx can't deduce a single consistent
	// type for one placeholder used in two different contexts, so it's passed
	// twice (as $1 and $4) instead.
	_, err := r.db.Exec(ctx, `
		UPDATE technicians
		SET approval_status = $1, rejection_reason = $2, is_verified = ($4 = 'approved'), updated_at = now()
		WHERE id = $3
	`, status, reason, id, status)
	return err
}
