package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type CategoryRepository struct {
	db *pgxpool.Pool
}

func NewCategoryRepository(db *pgxpool.Pool) *CategoryRepository {
	return &CategoryRepository{db: db}
}

func (r *CategoryRepository) Create(ctx context.Context, c *models.Category) (*models.Category, error) {
	if len(c.WarrantyOptions) == 0 {
		c.WarrantyOptions = []int32{7, 15, 30, 90}
	}
	err := r.db.QueryRow(ctx, `
		INSERT INTO categories (name, description, icon_url, base_price, is_active, warranty_options)
		VALUES ($1,$2,$3,$4,true,$5)
		RETURNING id, created_at
	`, c.Name, c.Description, c.IconURL, c.BasePrice, c.WarrantyOptions).Scan(&c.ID, &c.CreatedAt)
	if err != nil {
		return nil, err
	}
	c.IsActive = true
	return c, nil
}

func (r *CategoryRepository) List(ctx context.Context) ([]models.Category, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, name, COALESCE(description,''), COALESCE(icon_url,''), base_price, is_active, warranty_options, created_at
		FROM categories WHERE is_active = true ORDER BY name
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Category
	for rows.Next() {
		var c models.Category
		if err := rows.Scan(&c.ID, &c.Name, &c.Description, &c.IconURL, &c.BasePrice, &c.IsActive, &c.WarrantyOptions, &c.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, nil
}

func (r *CategoryRepository) GetByID(ctx context.Context, id string) (*models.Category, error) {
	var c models.Category
	err := r.db.QueryRow(ctx, `
		SELECT id, name, COALESCE(description,''), COALESCE(icon_url,''), base_price, is_active, warranty_options, created_at
		FROM categories WHERE id = $1
	`, id).Scan(&c.ID, &c.Name, &c.Description, &c.IconURL, &c.BasePrice, &c.IsActive, &c.WarrantyOptions, &c.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &c, nil
}

// UpdateWarrantyOptions is the admin-only knob for which warranty durations
// (in days) technicians in this category are allowed to offer — enforced
// server-side in BookingService.Complete, not just a UI hint.
func (r *CategoryRepository) UpdateWarrantyOptions(ctx context.Context, id string, days []int32) error {
	tag, err := r.db.Exec(ctx, `UPDATE categories SET warranty_options = $2 WHERE id = $1`, id, days)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}