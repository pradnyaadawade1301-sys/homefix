package service

import (
	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type AnalyticsService struct {
	repo *repository.AnalyticsRepository
}

func NewAnalyticsService(repo *repository.AnalyticsRepository) *AnalyticsService {
	return &AnalyticsService{repo: repo}
}

func (s *AnalyticsService) Dashboard(ctx context.Context) (*models.DashboardStats, error) {
	return s.repo.DashboardStats(ctx)
}

func (s *AnalyticsService) Revenue(ctx context.Context, from, to string) (*models.RevenueSummary, error) {
	return s.repo.RevenueSummary(ctx, from, to)
}

func (s *AnalyticsService) DailyRevenue(ctx context.Context, from, to string) ([]models.DailyMetric, error) {
	return s.repo.DailyRevenue(ctx, from, to)
}

func (s *AnalyticsService) DailyBookings(ctx context.Context, from, to string) ([]models.DailyMetric, error) {
	return s.repo.DailyBookings(ctx, from, to)
}

func (s *AnalyticsService) DailySignups(ctx context.Context, from, to string) ([]models.DailyMetric, error) {
	return s.repo.DailySignups(ctx, from, to)
}
