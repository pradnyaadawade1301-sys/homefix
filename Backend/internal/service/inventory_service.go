package service

import (
	"context"

	"homefix-backend/internal/models"
	"homefix-backend/internal/repository"
)

type InventoryService struct {
	repo *repository.InventoryRepository
}

func NewInventoryService(repo *repository.InventoryRepository) *InventoryService {
	return &InventoryService{repo: repo}
}

func (s *InventoryService) CreateSupplier(ctx context.Context, sup *models.Supplier) (*models.Supplier, error) {
	return s.repo.CreateSupplier(ctx, sup)
}

func (s *InventoryService) ListSuppliers(ctx context.Context) ([]models.Supplier, error) {
	return s.repo.ListSuppliers(ctx)
}

func (s *InventoryService) SetSupplierActive(ctx context.Context, id string, active bool) error {
	return s.repo.SetSupplierActive(ctx, id, active)
}

func (s *InventoryService) CreatePart(ctx context.Context, p *models.SparePart) (*models.SparePart, error) {
	return s.repo.CreateSparePart(ctx, p)
}

func (s *InventoryService) UpdatePart(ctx context.Context, p *models.SparePart) error {
	return s.repo.UpdateSparePart(ctx, p)
}

func (s *InventoryService) GetPart(ctx context.Context, id string) (*models.SparePart, error) {
	return s.repo.GetSparePart(ctx, id)
}

func (s *InventoryService) ListParts(ctx context.Context, categoryID string) ([]models.SparePart, error) {
	return s.repo.ListSpareParts(ctx, categoryID)
}

func (s *InventoryService) ListLowStock(ctx context.Context) ([]models.SparePart, error) {
	return s.repo.ListLowStock(ctx)
}

// AdjustStock is used both by the admin panel (manual restock/adjustment) and by
// the booking-completion flow (usage) — see BookingService for the latter.
func (s *InventoryService) AdjustStock(ctx context.Context, sparePartID, changeType string, delta int, bookingID, note, createdBy *string) (*models.SparePart, error) {
	return s.repo.AdjustStock(ctx, sparePartID, changeType, delta, bookingID, note, createdBy)
}

func (s *InventoryService) StockHistory(ctx context.Context, sparePartID string) ([]models.StockMovement, error) {
	return s.repo.ListStockMovements(ctx, sparePartID)
}

func (s *InventoryService) CreateOrder(ctx context.Context, o *models.SparePartOrder) (*models.SparePartOrder, error) {
	return s.repo.CreateOrder(ctx, o)
}

func (s *InventoryService) ListOrders(ctx context.Context) ([]models.SparePartOrder, error) {
	return s.repo.ListOrders(ctx)
}

func (s *InventoryService) ReceiveOrder(ctx context.Context, orderID string) error {
	return s.repo.ReceiveOrder(ctx, orderID)
}
