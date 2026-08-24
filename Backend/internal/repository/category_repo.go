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
	err := r.db.QueryRow(ctx, `
		INSERT INTO categories (name, description, icon_url, base_price, is_active)
		VALUES ($1,$2,$3,$4,true)
		RETURNING id, created_at
	`, c.Name, c.Description, c.IconURL, c.BasePrice).Scan(&c.ID, &c.CreatedAt)
	if err != nil {
		return nil, err
	}
	c.IsActive = true
	return c, nil
}

func (r *CategoryRepository) List(ctx context.Context) ([]models.Category, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, name, COALESCE(description,''), COALESCE(icon_url,''), base_price, is_active, created_at
		FROM categories WHERE is_active = true ORDER BY name
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Category
	for rows.Next() {
		var c models.Category
		if err := rows.Scan(&c.ID, &c.Name, &c.Description, &c.IconURL, &c.BasePrice, &c.IsActive, &c.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, nil
}

func (r *CategoryRepository) GetByID(ctx context.Context, id string) (*models.Category, error) {
	var c models.Category
	err := r.db.QueryRow(ctx, `
		SELECT id, name, COALESCE(description,''), COALESCE(icon_url,''), base_price, is_active, created_at
		FROM categories WHERE id = $1
	`, id).Scan(&c.ID, &c.Name, &c.Description, &c.IconURL, &c.BasePrice, &c.IsActive, &c.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &c, nil
}
