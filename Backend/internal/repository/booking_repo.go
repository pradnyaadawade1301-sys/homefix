package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type BookingRepository struct {
	db *pgxpool.Pool
}

func NewBookingRepository(db *pgxpool.Pool) *BookingRepository {
	return &BookingRepository{db: db}
}

func (r *BookingRepository) Create(ctx context.Context, b *models.Booking) (*models.Booking, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	err = tx.QueryRow(ctx, `
		INSERT INTO bookings (customer_id, category_id, address_id, status, problem_description, notes, images, scheduled_at, estimated_price)
		VALUES ($1,$2,$3,'requested',$4,$5,$6,$7,$8)
		RETURNING id, status, payment_status, created_at, updated_at
	`, b.CustomerID, b.CategoryID, b.AddressID, b.ProblemDescription, b.Notes, b.Images, b.ScheduledAt, b.EstimatedPrice,
	).Scan(&b.ID, &b.Status, &b.PaymentStatus, &b.CreatedAt, &b.UpdatedAt)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `INSERT INTO booking_status_history (booking_id, status, note) VALUES ($1,$2,$3)`,
		b.ID, models.BookingRequested, "Booking created")
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return b, nil
}

func (r *BookingRepository) GetByID(ctx context.Context, id string) (*models.Booking, error) {
	var b models.Booking
	err := r.db.QueryRow(ctx, `
		SELECT id, customer_id, technician_id, category_id, address_id, status, payment_status,
		       COALESCE(problem_description,''), notes, COALESCE(images, '{}'), scheduled_at, estimated_price, final_price, created_at, updated_at
		FROM bookings WHERE id = $1
	`, id).Scan(&b.ID, &b.CustomerID, &b.TechnicianID, &b.CategoryID, &b.AddressID, &b.Status, &b.PaymentStatus,
		&b.ProblemDescription, &b.Notes, &b.Images, &b.ScheduledAt, &b.EstimatedPrice, &b.FinalPrice, &b.CreatedAt, &b.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &b, nil
}

func (r *BookingRepository) ListByCustomer(ctx context.Context, customerID string) ([]models.Booking, error) {
	return r.listByColumn(ctx, "customer_id", customerID)
}

func (r *BookingRepository) ListByTechnician(ctx context.Context, technicianID string) ([]models.Booking, error) {
	return r.listByColumn(ctx, "technician_id", technicianID)
}

func (r *BookingRepository) listByColumn(ctx context.Context, col, val string) ([]models.Booking, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, customer_id, technician_id, category_id, address_id, status, payment_status,
		       COALESCE(problem_description,''), notes, COALESCE(images, '{}'), scheduled_at, estimated_price, final_price, created_at, updated_at
		FROM bookings WHERE `+col+` = $1 ORDER BY created_at DESC
	`, val)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Booking
	for rows.Next() {
		var b models.Booking
		if err := rows.Scan(&b.ID, &b.CustomerID, &b.TechnicianID, &b.CategoryID, &b.AddressID, &b.Status, &b.PaymentStatus,
			&b.ProblemDescription, &b.Notes, &b.Images, &b.ScheduledAt, &b.EstimatedPrice, &b.FinalPrice, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, nil
}

// SetPaymentStatus is only ever called from a verified payment confirmation/refund
// path (see UpiService.ConfirmPayment / Refund) — never directly from a client
// request — so a booking can't be marked "paid" without a UPI app actually having
// reported a successful transaction.
func (r *BookingRepository) SetPaymentStatus(ctx context.Context, bookingID, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE bookings SET payment_status = $1, updated_at = now() WHERE id = $2`, status, bookingID)
	return err
}

func (r *BookingRepository) AssignTechnician(ctx context.Context, bookingID, technicianID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `UPDATE bookings SET technician_id = $1, status = 'accepted', updated_at = now() WHERE id = $2`,
		technicianID, bookingID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `INSERT INTO booking_status_history (booking_id, status, note) VALUES ($1,'accepted','Technician assigned')`,
		bookingID)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *BookingRepository) UpdateStatus(ctx context.Context, bookingID, status, note string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `UPDATE bookings SET status = $1, updated_at = now() WHERE id = $2`, status, bookingID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `INSERT INTO booking_status_history (booking_id, status, note) VALUES ($1,$2,$3)`,
		bookingID, status, note)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *BookingRepository) SetFinalPrice(ctx context.Context, bookingID string, price float64) error {
	_, err := r.db.Exec(ctx, `UPDATE bookings SET final_price = $1, updated_at = now() WHERE id = $2`, price, bookingID)
	return err
}

func (r *BookingRepository) History(ctx context.Context, bookingID string) ([]models.BookingStatusHistory, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, booking_id, status, COALESCE(note,''), created_at
		FROM booking_status_history WHERE booking_id = $1 ORDER BY created_at ASC
	`, bookingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.BookingStatusHistory
	for rows.Next() {
		var h models.BookingStatusHistory
		if err := rows.Scan(&h.ID, &h.BookingID, &h.Status, &h.Note, &h.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, h)
	}
	return out, nil
}

// CountPriorBookings returns how many bookings this customer has previously made
// with this technician — used to decide first-time vs repeat-customer pricing at
// checkout (see UpiService.CreateOrder). A booking's own row isn't excluded by ID
// here since this is meant to be called BEFORE the booking being paid for is
// counted as "prior".
func (r *BookingRepository) CountPriorBookings(ctx context.Context, customerID, technicianID string) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM bookings WHERE customer_id = $1 AND technician_id = $2
	`, customerID, technicianID).Scan(&count)
	return count, err
}

// ListRepeatCustomersByTechnician returns customers who have booked this technician
// more than once, most-frequent first — powers the technician's "My Customers" /
// repeat-customer screen.
func (r *BookingRepository) ListRepeatCustomersByTechnician(ctx context.Context, technicianID string) ([]models.RepeatCustomer, error) {
	rows, err := r.db.Query(ctx, `
		SELECT b.customer_id, COALESCE(u.name,''), COALESCE(u.phone,''), COUNT(*) AS total_bookings, MAX(b.created_at) AS last_booking_at
		FROM bookings b
		JOIN users u ON u.id = b.customer_id
		WHERE b.technician_id = $1
		GROUP BY b.customer_id, u.name, u.phone
		HAVING COUNT(*) > 1
		ORDER BY total_bookings DESC, last_booking_at DESC
	`, technicianID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.RepeatCustomer
	for rows.Next() {
		var rc models.RepeatCustomer
		if err := rows.Scan(&rc.CustomerID, &rc.Name, &rc.Phone, &rc.TotalBookings, &rc.LastBookingAt); err != nil {
			return nil, err
		}
		out = append(out, rc)
	}
	return out, rows.Err()
}

// --- Booking chat (customer <-> assigned technician) ---

func (r *BookingRepository) CreateMessage(ctx context.Context, m *models.BookingMessage) (*models.BookingMessage, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO booking_messages (booking_id, sender_id, sender_role, content)
		VALUES ($1, $2, $3, $4)
		RETURNING id, booking_id, sender_id, sender_role, content, created_at`,
		m.BookingID, m.SenderID, m.SenderRole, m.Content)

	var out models.BookingMessage
	if err := row.Scan(&out.ID, &out.BookingID, &out.SenderID, &out.SenderRole, &out.Content, &out.CreatedAt); err != nil {
		return nil, err
	}
	return &out, nil
}

func (r *BookingRepository) ListMessages(ctx context.Context, bookingID string) ([]models.BookingMessage, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, booking_id, sender_id, sender_role, content, created_at
		FROM booking_messages WHERE booking_id = $1 ORDER BY created_at ASC`, bookingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.BookingMessage
	for rows.Next() {
		var m models.BookingMessage
		if err := rows.Scan(&m.ID, &m.BookingID, &m.SenderID, &m.SenderRole, &m.Content, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// --- Detailed listings (joined with customer/technician/address/category) ---
//
// detailedSelect is shared by GetDetailByID / ListByCustomerDetailed /
// ListByTechnicianDetailed so the column order (and therefore the scan order)
// only has to be kept in sync with scanDetailed in one place.
const detailedSelect = `
	SELECT b.id, b.customer_id, b.technician_id, b.category_id, b.address_id, b.status,
	       COALESCE(b.problem_description,''), b.notes, COALESCE(b.images, '{}'), b.scheduled_at, b.estimated_price, b.final_price,
	       b.created_at, b.updated_at,
	       c.name AS category_name,
	       a.label, a.line1, COALESCE(a.line2,''), a.city, a.state, a.pincode,
	       cu.name AS customer_name, cu.phone AS customer_phone,
	       t.id, COALESCE(tu.name,''), COALESCE(tu.phone,''),
	       t.experience_years, t.rating_avg, t.rating_count, t.is_verified
	FROM bookings b
	JOIN categories c ON c.id = b.category_id
	JOIN addresses a ON a.id = b.address_id
	JOIN users cu ON cu.id = b.customer_id
	LEFT JOIN technicians t ON t.id = b.technician_id
	LEFT JOIN users tu ON tu.id = t.user_id
`

func scanBookingDetail(row pgx.Row) (*models.BookingDetail, error) {
	var d models.BookingDetail
	var addr models.BookingAddressInfo
	var custName, custPhone string
	var techID, techName, techPhone *string
	var techExp *int
	var techRating *float64
	var techRatingCount *int
	var techVerified *bool

	err := row.Scan(
		&d.ID, &d.CustomerID, &d.TechnicianID, &d.CategoryID, &d.AddressID, &d.Status,
		&d.ProblemDescription, &d.Notes, &d.Images, &d.ScheduledAt, &d.EstimatedPrice, &d.FinalPrice,
		&d.CreatedAt, &d.UpdatedAt,
		&d.CategoryName,
		&addr.Label, &addr.Line1, &addr.Line2, &addr.City, &addr.State, &addr.Pincode,
		&custName, &custPhone,
		&techID, &techName, &techPhone,
		&techExp, &techRating, &techRatingCount, &techVerified,
	)
	if err != nil {
		return nil, err
	}

	d.Address = &addr
	d.Customer = &models.BookingCustomerInfo{ID: d.CustomerID, Name: custName, Phone: custPhone}

	if techID != nil {
		d.Technician = &models.BookingTechnicianInfo{
			ID:              *techID,
			Name:            derefOrEmpty(techName),
			Phone:           derefOrEmpty(techPhone),
			CategoryName:    d.CategoryName,
			ExperienceYears: derefIntOrZero(techExp),
			RatingAvg:       derefFloatOrZero(techRating),
			RatingCount:     derefIntOrZero(techRatingCount),
			IsVerified:      derefBoolOrFalse(techVerified),
		}
	}
	return &d, nil
}

func derefOrEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
func derefIntOrZero(i *int) int {
	if i == nil {
		return 0
	}
	return *i
}
func derefFloatOrZero(f *float64) float64 {
	if f == nil {
		return 0
	}
	return *f
}
func derefBoolOrFalse(b *bool) bool {
	if b == nil {
		return false
	}
	return *b
}

func (r *BookingRepository) GetDetailByID(ctx context.Context, id string) (*models.BookingDetail, error) {
	d, err := scanBookingDetail(r.db.QueryRow(ctx, detailedSelect+" WHERE b.id = $1", id))
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return d, nil
}

func (r *BookingRepository) ListByCustomerDetailed(ctx context.Context, customerID string) ([]models.BookingDetail, error) {
	return r.listDetailedByColumn(ctx, "b.customer_id", customerID)
}

// ListAllDetailed powers the admin panel's Booking Management screen. status == ""
// lists every booking regardless of status.
func (r *BookingRepository) ListAllDetailed(ctx context.Context, status string) ([]models.BookingDetail, error) {
	query := detailedSelect
	args := []interface{}{}
	if status != "" {
		query += " WHERE b.status = $1"
		args = append(args, status)
	}
	query += " ORDER BY b.created_at DESC LIMIT 200"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.BookingDetail
	for rows.Next() {
		d, err := scanBookingDetail(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *d)
	}
	return out, rows.Err()
}

func (r *BookingRepository) ListByTechnicianDetailed(ctx context.Context, technicianID string) ([]models.BookingDetail, error) {
	return r.listDetailedByColumn(ctx, "b.technician_id", technicianID)
}

// ListByCustomerAndTechnicianDetailed returns every booking between a specific
// customer and technician, newest first — powers the technician's per-customer
// Service History screen (reached from the repeat-customers list).
func (r *BookingRepository) ListByCustomerAndTechnicianDetailed(ctx context.Context, customerID, technicianID string) ([]models.BookingDetail, error) {
	rows, err := r.db.Query(ctx, detailedSelect+" WHERE b.customer_id = $1 AND b.technician_id = $2 ORDER BY b.created_at DESC", customerID, technicianID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.BookingDetail
	for rows.Next() {
		d, err := scanBookingDetail(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *d)
	}
	return out, rows.Err()
}

func (r *BookingRepository) listDetailedByColumn(ctx context.Context, col, val string) ([]models.BookingDetail, error) {
	rows, err := r.db.Query(ctx, detailedSelect+" WHERE "+col+" = $1 ORDER BY b.created_at DESC", val)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.BookingDetail
	for rows.Next() {
		d, err := scanBookingDetail(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *d)
	}
	return out, rows.Err()
}