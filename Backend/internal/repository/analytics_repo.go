package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type AnalyticsRepository struct {
	db *pgxpool.Pool
}

func NewAnalyticsRepository(db *pgxpool.Pool) *AnalyticsRepository {
	return &AnalyticsRepository{db: db}
}

func (r *AnalyticsRepository) DashboardStats(ctx context.Context) (*models.DashboardStats, error) {
	var s models.DashboardStats

	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE role = 'customer'`).Scan(&s.TotalCustomers); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM technicians`).Scan(&s.TotalTechnicians); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM technicians WHERE approval_status = 'pending'`).Scan(&s.PendingTechnicianKyc); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM bookings`).Scan(&s.TotalBookings); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM bookings WHERE created_at::date = CURRENT_DATE`).Scan(&s.BookingsToday); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM disputes WHERE status IN ('open','under_review')`).Scan(&s.OpenDisputes); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM payments WHERE status = 'paid'`).Scan(&s.TotalRevenue); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM payments WHERE status = 'paid' AND updated_at::date = CURRENT_DATE`).Scan(&s.RevenueToday); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM ai_diagnosis_sessions`).Scan(&s.AiSessionsTotal); err != nil {
		return nil, err
	}

	var consultTotal, consultEscalated int
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM consultations`).Scan(&consultTotal); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM consultations WHERE escalated_booking_id IS NOT NULL`).Scan(&consultEscalated); err != nil {
		return nil, err
	}
	if consultTotal > 0 {
		s.ConsultationToBookingPct = float64(consultEscalated) / float64(consultTotal) * 100
	}

	return &s, nil
}

func (r *AnalyticsRepository) RevenueSummary(ctx context.Context, from, to string) (*models.RevenueSummary, error) {
	var s models.RevenueSummary
	err := r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount),0), COALESCE(SUM(platform_commission),0),
		       COALESCE(SUM(technician_earning),0), COUNT(*) FILTER (WHERE status = 'paid')
		FROM payments
		WHERE status IN ('paid','refunded') AND created_at::date BETWEEN $1::date AND $2::date
	`, from, to).Scan(&s.TotalRevenue, &s.PlatformCommission, &s.TechnicianPayouts, &s.PaidBookingsCount)
	if err != nil {
		return nil, err
	}
	err = r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount),0) FROM payments WHERE status = 'refunded' AND created_at::date BETWEEN $1::date AND $2::date
	`, from, to).Scan(&s.RefundedAmount)
	return &s, err
}

// DailyRevenue powers the revenue chart / daily-weekly-monthly reports and CSV export.
func (r *AnalyticsRepository) DailyRevenue(ctx context.Context, from, to string) ([]models.DailyMetric, error) {
	rows, err := r.db.Query(ctx, `
		SELECT to_char(updated_at::date, 'YYYY-MM-DD') AS d, COALESCE(SUM(amount),0)
		FROM payments
		WHERE status = 'paid' AND updated_at::date BETWEEN $1::date AND $2::date
		GROUP BY d ORDER BY d ASC
	`, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.DailyMetric
	for rows.Next() {
		var m models.DailyMetric
		if err := rows.Scan(&m.Date, &m.Value); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *AnalyticsRepository) DailyBookings(ctx context.Context, from, to string) ([]models.DailyMetric, error) {
	rows, err := r.db.Query(ctx, `
		SELECT to_char(created_at::date, 'YYYY-MM-DD') AS d, COUNT(*)
		FROM bookings
		WHERE created_at::date BETWEEN $1::date AND $2::date
		GROUP BY d ORDER BY d ASC
	`, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.DailyMetric
	for rows.Next() {
		var m models.DailyMetric
		if err := rows.Scan(&m.Date, &m.Value); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *AnalyticsRepository) DailySignups(ctx context.Context, from, to string) ([]models.DailyMetric, error) {
	rows, err := r.db.Query(ctx, `
		SELECT to_char(created_at::date, 'YYYY-MM-DD') AS d, COUNT(*)
		FROM users
		WHERE created_at::date BETWEEN $1::date AND $2::date
		GROUP BY d ORDER BY d ASC
	`, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.DailyMetric
	for rows.Next() {
		var m models.DailyMetric
		if err := rows.Scan(&m.Date, &m.Value); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}
