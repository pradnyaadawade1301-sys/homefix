package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type InventoryRepository struct {
	db *pgxpool.Pool
}

func NewInventoryRepository(db *pgxpool.Pool) *InventoryRepository {
	return &InventoryRepository{db: db}
}

// --- Suppliers ---

func (r *InventoryRepository) CreateSupplier(ctx context.Context, s *models.Supplier) (*models.Supplier, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO suppliers (name, contact_person, phone, email, address)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, is_active, created_at
	`, s.Name, s.ContactPerson, s.Phone, s.Email, s.Address).Scan(&s.ID, &s.IsActive, &s.CreatedAt)
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (r *InventoryRepository) ListSuppliers(ctx context.Context) ([]models.Supplier, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, name, COALESCE(contact_person,''), COALESCE(phone,''), COALESCE(email,''),
		       COALESCE(address,''), is_active, created_at
		FROM suppliers ORDER BY name ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Supplier
	for rows.Next() {
		var s models.Supplier
		if err := rows.Scan(&s.ID, &s.Name, &s.ContactPerson, &s.Phone, &s.Email, &s.Address, &s.IsActive, &s.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

func (r *InventoryRepository) SetSupplierActive(ctx context.Context, id string, active bool) error {
	_, err := r.db.Exec(ctx, `UPDATE suppliers SET is_active = $2 WHERE id = $1`, id, active)
	return err
}

// --- Spare parts ---

const sparePartColumns = `id, category_id, supplier_id, name, sku, COALESCE(description,''),
	       unit_price, stock_quantity, reorder_level, is_active, created_at, updated_at`

func scanSparePart(row pgx.Row) (*models.SparePart, error) {
	var p models.SparePart
	err := row.Scan(&p.ID, &p.CategoryID, &p.SupplierID, &p.Name, &p.SKU, &p.Description,
		&p.UnitPrice, &p.StockQuantity, &p.ReorderLevel, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *InventoryRepository) CreateSparePart(ctx context.Context, p *models.SparePart) (*models.SparePart, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO spare_parts (category_id, supplier_id, name, sku, description, unit_price, stock_quantity, reorder_level)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id, is_active, created_at, updated_at
	`, p.CategoryID, p.SupplierID, p.Name, p.SKU, p.Description, p.UnitPrice, p.StockQuantity, p.ReorderLevel,
	).Scan(&p.ID, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *InventoryRepository) UpdateSparePart(ctx context.Context, p *models.SparePart) error {
	_, err := r.db.Exec(ctx, `
		UPDATE spare_parts
		SET category_id = $2, supplier_id = $3, name = $4, sku = $5, description = $6,
		    unit_price = $7, reorder_level = $8, is_active = $9, updated_at = now()
		WHERE id = $1
	`, p.ID, p.CategoryID, p.SupplierID, p.Name, p.SKU, p.Description, p.UnitPrice, p.ReorderLevel, p.IsActive)
	return err
}

func (r *InventoryRepository) GetSparePart(ctx context.Context, id string) (*models.SparePart, error) {
	p, err := scanSparePart(r.db.QueryRow(ctx, `SELECT `+sparePartColumns+` FROM spare_parts WHERE id = $1`, id))
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return p, err
}

func (r *InventoryRepository) ListSpareParts(ctx context.Context, categoryID string) ([]models.SparePart, error) {
	query := `SELECT ` + sparePartColumns + ` FROM spare_parts`
	var rows pgx.Rows
	var err error
	if categoryID != "" {
		rows, err = r.db.Query(ctx, query+` WHERE category_id = $1 ORDER BY name ASC`, categoryID)
	} else {
		rows, err = r.db.Query(ctx, query+` ORDER BY name ASC`)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.SparePart
	for rows.Next() {
		p, err := scanSparePart(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

func (r *InventoryRepository) ListLowStock(ctx context.Context) ([]models.SparePart, error) {
	rows, err := r.db.Query(ctx, `SELECT `+sparePartColumns+` FROM spare_parts WHERE stock_quantity <= reorder_level AND is_active ORDER BY stock_quantity ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.SparePart
	for rows.Next() {
		p, err := scanSparePart(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

// AdjustStock is the only way stock_quantity ever changes — always inside a
// transaction with the corresponding movement log entry, and it rejects a delta
// that would take stock negative.
func (r *InventoryRepository) AdjustStock(ctx context.Context, sparePartID, changeType string, delta int, bookingID, note *string, createdBy *string) (*models.SparePart, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var currentQty int
	if err := tx.QueryRow(ctx, `SELECT stock_quantity FROM spare_parts WHERE id = $1 FOR UPDATE`, sparePartID).Scan(&currentQty); err != nil {
		return nil, err
	}
	if currentQty+delta < 0 {
		return nil, errors.New("insufficient stock")
	}

	if _, err := tx.Exec(ctx, `UPDATE spare_parts SET stock_quantity = stock_quantity + $2, updated_at = now() WHERE id = $1`, sparePartID, delta); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO spare_part_stock_movements (spare_part_id, change_type, quantity_delta, booking_id, note, created_by)
		VALUES ($1,$2,$3,$4,$5,$6)
	`, sparePartID, changeType, delta, bookingID, note, createdBy); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetSparePart(ctx, sparePartID)
}

func (r *InventoryRepository) ListStockMovements(ctx context.Context, sparePartID string) ([]models.StockMovement, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, spare_part_id, change_type, quantity_delta, booking_id, COALESCE(note,''), created_by, created_at
		FROM spare_part_stock_movements WHERE spare_part_id = $1 ORDER BY created_at DESC
	`, sparePartID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.StockMovement
	for rows.Next() {
		var m models.StockMovement
		if err := rows.Scan(&m.ID, &m.SparePartID, &m.ChangeType, &m.QuantityDelta, &m.BookingID, &m.Note, &m.CreatedBy, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// --- Purchase orders ---

func (r *InventoryRepository) CreateOrder(ctx context.Context, o *models.SparePartOrder) (*models.SparePartOrder, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO spare_part_orders (spare_part_id, supplier_id, quantity, unit_cost, ordered_by)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, status, created_at
	`, o.SparePartID, o.SupplierID, o.Quantity, o.UnitCost, o.OrderedBy).Scan(&o.ID, &o.Status, &o.CreatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

func (r *InventoryRepository) ListOrders(ctx context.Context) ([]models.SparePartOrder, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, spare_part_id, supplier_id, quantity, unit_cost, status, ordered_by, created_at, received_at
		FROM spare_part_orders ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.SparePartOrder
	for rows.Next() {
		var o models.SparePartOrder
		if err := rows.Scan(&o.ID, &o.SparePartID, &o.SupplierID, &o.Quantity, &o.UnitCost, &o.Status, &o.OrderedBy, &o.CreatedAt, &o.ReceivedAt); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// ReceiveOrder marks a purchase order received and restocks the spare part in one
// transaction (so the stock movement log and the order status can never drift
// apart).
func (r *InventoryRepository) ReceiveOrder(ctx context.Context, orderID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var sparePartID string
	var quantity int
	var status string
	if err := tx.QueryRow(ctx, `SELECT spare_part_id, quantity, status FROM spare_part_orders WHERE id = $1 FOR UPDATE`, orderID).
		Scan(&sparePartID, &quantity, &status); err != nil {
		return err
	}
	if status != "ordered" {
		return errors.New("order already " + status)
	}

	if _, err := tx.Exec(ctx, `UPDATE spare_part_orders SET status = 'received', received_at = now() WHERE id = $1`, orderID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE spare_parts SET stock_quantity = stock_quantity + $2, updated_at = now() WHERE id = $1`, sparePartID, quantity); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO spare_part_stock_movements (spare_part_id, change_type, quantity_delta, note)
		VALUES ($1, 'restock', $2, 'Purchase order received')
	`, sparePartID, quantity); err != nil {
		return err
	}
	return tx.Commit(ctx)
}