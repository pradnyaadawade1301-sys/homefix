package service

import (
	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type CmsService struct {
	repo *repository.CmsRepository
}

func NewCmsService(repo *repository.CmsRepository) *CmsService {
	return &CmsService{repo: repo}
}

func (s *CmsService) GetPage(ctx context.Context, key string) (*models.CmsPage, error) {
	return s.repo.GetPage(ctx, key)
}

func (s *CmsService) ListPages(ctx context.Context) ([]models.CmsPage, error) {
	return s.repo.ListPages(ctx)
}

func (s *CmsService) SavePage(ctx context.Context, key, title, content, updatedBy string) (*models.CmsPage, error) {
	return s.repo.UpsertPage(ctx, key, title, content, updatedBy)
}

func (s *CmsService) ListFaqs(ctx context.Context, activeOnly bool) ([]models.CmsFaq, error) {
	return s.repo.ListFaqs(ctx, activeOnly)
}

func (s *CmsService) CreateFaq(ctx context.Context, f *models.CmsFaq) (*models.CmsFaq, error) {
	return s.repo.CreateFaq(ctx, f)
}

func (s *CmsService) SetFaqActive(ctx context.Context, id string, active bool) error {
	return s.repo.SetFaqActive(ctx, id, active)
}

func (s *CmsService) DeleteFaq(ctx context.Context, id string) error {
	return s.repo.DeleteFaq(ctx, id)
}

func (s *CmsService) ListAnnouncements(ctx context.Context, activeOnly bool) ([]models.CmsAnnouncement, error) {
	return s.repo.ListAnnouncements(ctx, activeOnly)
}

func (s *CmsService) CreateAnnouncement(ctx context.Context, a *models.CmsAnnouncement) (*models.CmsAnnouncement, error) {
	return s.repo.CreateAnnouncement(ctx, a)
}

func (s *CmsService) SetAnnouncementActive(ctx context.Context, id string, active bool) error {
	return s.repo.SetAnnouncementActive(ctx, id, active)
}

func (s *CmsService) ListBanners(ctx context.Context, activeOnly bool) ([]models.CmsBanner, error) {
	return s.repo.ListBanners(ctx, activeOnly)
}

func (s *CmsService) CreateBanner(ctx context.Context, b *models.CmsBanner) (*models.CmsBanner, error) {
	return s.repo.CreateBanner(ctx, b)
}

func (s *CmsService) SetBannerActive(ctx context.Context, id string, active bool) error {
	return s.repo.SetBannerActive(ctx, id, active)
}
