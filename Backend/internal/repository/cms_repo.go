package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type CmsRepository struct {
	db *pgxpool.Pool
}

func NewCmsRepository(db *pgxpool.Pool) *CmsRepository {
	return &CmsRepository{db: db}
}

// --- Pages (About Us / Privacy Policy / Terms / Help Center) ---

func (r *CmsRepository) GetPage(ctx context.Context, key string) (*models.CmsPage, error) {
	var p models.CmsPage
	err := r.db.QueryRow(ctx, `SELECT id, key, title, content, updated_by, updated_at FROM cms_pages WHERE key = $1`, key).
		Scan(&p.ID, &p.Key, &p.Title, &p.Content, &p.UpdatedBy, &p.UpdatedAt)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *CmsRepository) ListPages(ctx context.Context) ([]models.CmsPage, error) {
	rows, err := r.db.Query(ctx, `SELECT id, key, title, content, updated_by, updated_at FROM cms_pages ORDER BY key ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.CmsPage
	for rows.Next() {
		var p models.CmsPage
		if err := rows.Scan(&p.ID, &p.Key, &p.Title, &p.Content, &p.UpdatedBy, &p.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// UpsertPage creates or updates a page by its unique key — the admin panel always
// has exactly one editable row per (about_us, privacy_policy, terms_conditions,
// help_center).
func (r *CmsRepository) UpsertPage(ctx context.Context, key, title, content, updatedBy string) (*models.CmsPage, error) {
	var p models.CmsPage
	err := r.db.QueryRow(ctx, `
		INSERT INTO cms_pages (key, title, content, updated_by)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (key) DO UPDATE SET title = $2, content = $3, updated_by = $4, updated_at = now()
		RETURNING id, key, title, content, updated_by, updated_at
	`, key, title, content, updatedBy).Scan(&p.ID, &p.Key, &p.Title, &p.Content, &p.UpdatedBy, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// --- FAQs ---

func (r *CmsRepository) ListFaqs(ctx context.Context, activeOnly bool) ([]models.CmsFaq, error) {
	query := `SELECT id, question, answer, sort_order, is_active, created_at FROM cms_faqs`
	if activeOnly {
		query += ` WHERE is_active`
	}
	query += ` ORDER BY sort_order ASC, created_at ASC`

	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.CmsFaq
	for rows.Next() {
		var f models.CmsFaq
		if err := rows.Scan(&f.ID, &f.Question, &f.Answer, &f.SortOrder, &f.IsActive, &f.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func (r *CmsRepository) CreateFaq(ctx context.Context, f *models.CmsFaq) (*models.CmsFaq, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO cms_faqs (question, answer, sort_order) VALUES ($1,$2,$3)
		RETURNING id, is_active, created_at
	`, f.Question, f.Answer, f.SortOrder).Scan(&f.ID, &f.IsActive, &f.CreatedAt)
	if err != nil {
		return nil, err
	}
	return f, nil
}

func (r *CmsRepository) SetFaqActive(ctx context.Context, id string, active bool) error {
	_, err := r.db.Exec(ctx, `UPDATE cms_faqs SET is_active = $2 WHERE id = $1`, id, active)
	return err
}

func (r *CmsRepository) DeleteFaq(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM cms_faqs WHERE id = $1`, id)
	return err
}

// --- Announcements ---

func (r *CmsRepository) ListAnnouncements(ctx context.Context, activeOnly bool) ([]models.CmsAnnouncement, error) {
	query := `SELECT id, title, body, is_active, starts_at, ends_at, created_at FROM cms_announcements`
	if activeOnly {
		query += ` WHERE is_active AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at >= now())`
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.CmsAnnouncement
	for rows.Next() {
		var a models.CmsAnnouncement
		if err := rows.Scan(&a.ID, &a.Title, &a.Body, &a.IsActive, &a.StartsAt, &a.EndsAt, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *CmsRepository) CreateAnnouncement(ctx context.Context, a *models.CmsAnnouncement) (*models.CmsAnnouncement, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO cms_announcements (title, body, starts_at, ends_at) VALUES ($1,$2,$3,$4)
		RETURNING id, is_active, created_at
	`, a.Title, a.Body, a.StartsAt, a.EndsAt).Scan(&a.ID, &a.IsActive, &a.CreatedAt)
	if err != nil {
		return nil, err
	}
	return a, nil
}

func (r *CmsRepository) SetAnnouncementActive(ctx context.Context, id string, active bool) error {
	_, err := r.db.Exec(ctx, `UPDATE cms_announcements SET is_active = $2 WHERE id = $1`, id, active)
	return err
}

// --- Banners ---

func (r *CmsRepository) ListBanners(ctx context.Context, activeOnly bool) ([]models.CmsBanner, error) {
	query := `SELECT id, COALESCE(title,''), image_url, COALESCE(link_url,''), sort_order, is_active, created_at FROM cms_banners`
	if activeOnly {
		query += ` WHERE is_active`
	}
	query += ` ORDER BY sort_order ASC`

	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.CmsBanner
	for rows.Next() {
		var b models.CmsBanner
		if err := rows.Scan(&b.ID, &b.Title, &b.ImageURL, &b.LinkURL, &b.SortOrder, &b.IsActive, &b.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r *CmsRepository) CreateBanner(ctx context.Context, b *models.CmsBanner) (*models.CmsBanner, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO cms_banners (title, image_url, link_url, sort_order) VALUES ($1,$2,$3,$4)
		RETURNING id, is_active, created_at
	`, b.Title, b.ImageURL, b.LinkURL, b.SortOrder).Scan(&b.ID, &b.IsActive, &b.CreatedAt)
	if err != nil {
		return nil, err
	}
	return b, nil
}

func (r *CmsRepository) SetBannerActive(ctx context.Context, id string, active bool) error {
	_, err := r.db.Exec(ctx, `UPDATE cms_banners SET is_active = $2 WHERE id = $1`, id, active)
	return err
}
