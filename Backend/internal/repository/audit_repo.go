package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type AuditRepository struct {
	db *pgxpool.Pool
}

func NewAuditRepository(db *pgxpool.Pool) *AuditRepository {
	return &AuditRepository{db: db}
}

// Log records one admin-panel action. Called from admin.RequireAdminSession's
// wrapped handlers (see internal/admin) — never from the Flutter-facing API.
func (r *AuditRepository) Log(ctx context.Context, adminUserID, action, entityType, entityID, detailsJSON, ip string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO audit_logs (admin_user_id, action, entity_type, entity_id, details, ip_address)
		VALUES ($1,$2,$3,NULLIF($4,''),NULLIF($5,'')::jsonb,$6)
	`, adminUserID, action, entityType, entityID, detailsJSON, ip)
	return err
}

func (r *AuditRepository) List(ctx context.Context, limit int) ([]models.AuditLog, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	rows, err := r.db.Query(ctx, `
		SELECT a.id, a.admin_user_id, a.action, a.entity_type, COALESCE(a.entity_id,''),
		       COALESCE(a.details::text,''), COALESCE(a.ip_address,''), a.created_at, COALESCE(u.name,'')
		FROM audit_logs a
		JOIN users u ON u.id = a.admin_user_id
		ORDER BY a.created_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.AuditLog
	for rows.Next() {
		var l models.AuditLog
		if err := rows.Scan(&l.ID, &l.AdminUserID, &l.Action, &l.EntityType, &l.EntityID, &l.Details, &l.IPAddress, &l.CreatedAt, &l.AdminName); err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}
