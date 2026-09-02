package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

// ErrBookingAlreadyAssigned is returned by AssignTechnician when the booking's
// status was no longer "requested" at the moment of the (atomic) DB update —
// i.e. another technician already grabbed it. Callers should surface this as
// a "someone else already accepted this booking" error, not a generic 500.
var ErrBookingAlreadyAssigned = errors.New("booking already assigned to another technician")

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
		       COALESCE(problem_description,''), notes, COALESCE(images, '{}'), scheduled_at, estimated_price, final_price, otp_code, otp_verified_at,
		       visit_fee_amount, visit_fee_status, created_at, updated_at
		FROM bookings WHERE id = $1
	`, id).Scan(&b.ID, &b.CustomerID, &b.TechnicianID, &b.CategoryID, &b.AddressID, &b.Status, &b.PaymentStatus,
		&b.ProblemDescription, &b.Notes, &b.Images, &b.ScheduledAt, &b.EstimatedPrice, &b.FinalPrice, &b.OTPCode, &b.OTPVerifiedAt,
		&b.VisitFeeAmount, &b.VisitFeeStatus, &b.CreatedAt, &b.UpdatedAt)
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

// SetVisitFeeRequired marks a booking as needing the ₹99 pre-visit inspection
// fee before the technician can head out — called once, right when a
// consultation is escalated into a booking (see ConsultationService.Escalate).
func (r *BookingRepository) SetVisitFeeRequired(ctx context.Context, bookingID string, amount float64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE bookings SET visit_fee_amount = $1, visit_fee_status = 'pending', updated_at = now() WHERE id = $2
	`, amount, bookingID)
	return err
}

// SetVisitFeeStatus moves the visit-fee status forward (pending -> paid on
// verified payment, paid -> refunded on cancellation).
func (r *BookingRepository) SetVisitFeeStatus(ctx context.Context, bookingID, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE bookings SET visit_fee_status = $1, updated_at = now() WHERE id = $2`, status, bookingID)
	return err
}

// AssignTechnician atomically assigns a technician only if the booking is still
// "requested" — the WHERE status='requested' guard + RowsAffected check is what
// actually prevents double-booking when two technicians accept at the same time;
// the row lock inside this single UPDATE statement means only one of two
// concurrent callers can win, unlike a separate read-then-write.
func (r *BookingRepository) AssignTechnician(ctx context.Context, bookingID, technicianID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx, `UPDATE bookings SET technician_id = $1, status = 'accepted', updated_at = now() WHERE id = $2 AND status = 'requested'`,
		technicianID, bookingID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrBookingAlreadyAssigned
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

// ListRepeatTechniciansByCustomer is the customer-side mirror of
// ListRepeatCustomersByTechnician — technicians this customer has booked more
// than once, most-frequent first — powers the customer's "My Technicians"
// (repeat technicians) screen.
func (r *BookingRepository) ListRepeatTechniciansByCustomer(ctx context.Context, customerID string) ([]models.RepeatTechnician, error) {
	rows, err := r.db.Query(ctx, `
		SELECT b.technician_id, COALESCE(u.name,''), COALESCE(u.phone,''),
		       COALESCE(cat.name,''), COALESCE(t.profile_photo_url,''), COALESCE(t.rating_avg,0),
		       COUNT(*) AS total_bookings, MAX(b.created_at) AS last_booking_at
		FROM bookings b
		JOIN technicians t ON t.id = b.technician_id
		JOIN users u ON u.id = t.user_id
		LEFT JOIN categories cat ON cat.id = t.category_id
		WHERE b.customer_id = $1 AND b.technician_id IS NOT NULL
		GROUP BY b.technician_id, u.name, u.phone, cat.name, t.profile_photo_url, t.rating_avg
		HAVING COUNT(*) > 1
		ORDER BY total_bookings DESC, last_booking_at DESC
	`, customerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.RepeatTechnician
	for rows.Next() {
		var rt models.RepeatTechnician
		if err := rows.Scan(&rt.TechnicianID, &rt.Name, &rt.Phone, &rt.CategoryName,
			&rt.ProfilePhotoURL, &rt.RatingAvg, &rt.TotalBookings, &rt.LastBookingAt); err != nil {
			return nil, err
		}
		out = append(out, rt)
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
	       b.otp_code, b.otp_verified_at,
	       b.visit_fee_amount, b.visit_fee_status,
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
		&d.OTPCode, &d.OTPVerifiedAt,
		&d.VisitFeeAmount, &d.VisitFeeStatus,
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

// --- OTP verification (customer confirms technician identity on-site) ---

// SetOTP stores a freshly generated OTP for the booking, clearing any
// previous verification — called when the technician marks themselves
// "arrived" so the customer's app can display a fresh code.
func (r *BookingRepository) SetOTP(ctx context.Context, bookingID, otp string) error {
	_, err := r.db.Exec(ctx, `UPDATE bookings SET otp_code = $1, otp_verified_at = NULL, updated_at = now() WHERE id = $2`,
		otp, bookingID)
	return err
}

// GetOTP returns the currently-stored (unverified) OTP for a booking, or ""
// if none has been generated yet or it's already been verified. This is
// what the customer's app polls/fetches to show the code on-screen.
func (r *BookingRepository) GetOTP(ctx context.Context, bookingID string) (string, error) {
	var otp *string
	var verifiedAt *time.Time
	err := r.db.QueryRow(ctx, `SELECT otp_code, otp_verified_at FROM bookings WHERE id = $1`, bookingID).Scan(&otp, &verifiedAt)
	if err != nil {
		return "", err
	}
	if otp == nil || verifiedAt != nil {
		return "", nil
	}
	return *otp, nil
}

// VerifyOTP checks the code the technician entered against the one stored
// for the booking. On success it stamps otp_verified_at so the service
// layer can safely allow the "inspecting" status transition.
func (r *BookingRepository) VerifyOTP(ctx context.Context, bookingID, otp string) (bool, error) {
	var stored *string
	err := r.db.QueryRow(ctx, `SELECT otp_code FROM bookings WHERE id = $1`, bookingID).Scan(&stored)
	if err != nil {
		return false, err
	}
	if stored == nil || *stored == "" || *stored != otp {
		return false, nil
	}
	_, err = r.db.Exec(ctx, `UPDATE bookings SET otp_verified_at = now(), updated_at = now() WHERE id = $1`, bookingID)
	if err != nil {
		return false, err
	}
	return true, nil
}

// --- Live technician location for a booking's tracking screen ---

// TechnicianLocationForBooking returns the assigned technician's last known
// lat/lng (reusing technicians.current_lat/current_lng, already kept fresh
// by PATCH /technicians/:id/location) plus when it was last updated. Returns
// nil, nil, nil, nil if no technician is assigned yet.
func (r *BookingRepository) TechnicianLocationForBooking(ctx context.Context, bookingID string) (lat, lng *float64, updatedAt *time.Time, err error) {
	err = r.db.QueryRow(ctx, `
		SELECT t.current_lat, t.current_lng, t.updated_at
		FROM bookings b
		JOIN technicians t ON t.id = b.technician_id
		WHERE b.id = $1
	`, bookingID).Scan(&lat, &lng, &updatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, nil, nil
	}
	return lat, lng, updatedAt, err
}

// --- Service estimate (Decline / Discuss / Approve) ---

// UpsertEstimate creates the booking's estimate on first save, or replaces
// the items/total/note on a later edit (e.g. after the customer asked to
// "discuss" and the technician revises it) — always leaving status back at
// "pending" so the customer sees the new number needs a fresh decision.
func (r *BookingRepository) UpsertEstimate(ctx context.Context, bookingID string, items []models.BookingEstimateItem, note string) (*models.BookingEstimate, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var total float64
	for _, it := range items {
		total += it.Amount
	}

	var estimateID string
	err = tx.QueryRow(ctx, `
		INSERT INTO booking_estimates (booking_id, status, total_amount, note)
		VALUES ($1, 'pending', $2, $3)
		ON CONFLICT (booking_id) DO UPDATE
			SET status = 'pending', total_amount = EXCLUDED.total_amount, note = EXCLUDED.note, updated_at = now()
		RETURNING id
	`, bookingID, total, note).Scan(&estimateID)
	if err != nil {
		return nil, err
	}

	if _, err := tx.Exec(ctx, `DELETE FROM booking_estimate_items WHERE estimate_id = $1`, estimateID); err != nil {
		return nil, err
	}
	for _, it := range items {
		if _, err := tx.Exec(ctx,
			`INSERT INTO booking_estimate_items (estimate_id, description, amount) VALUES ($1,$2,$3)`,
			estimateID, it.Description, it.Amount); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetEstimate(ctx, bookingID)
}

// GetEstimate returns the booking's current estimate (with its line items),
// or nil if the technician hasn't raised one yet.
func (r *BookingRepository) GetEstimate(ctx context.Context, bookingID string) (*models.BookingEstimate, error) {
	var e models.BookingEstimate
	err := r.db.QueryRow(ctx, `
		SELECT id, booking_id, status, total_amount, COALESCE(note,''), created_at, updated_at
		FROM booking_estimates WHERE booking_id = $1
	`, bookingID).Scan(&e.ID, &e.BookingID, &e.Status, &e.Total, &e.Note, &e.CreatedAt, &e.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	rows, err := r.db.Query(ctx, `SELECT id, description, amount FROM booking_estimate_items WHERE estimate_id = $1`, e.ID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var it models.BookingEstimateItem
		if err := rows.Scan(&it.ID, &it.Description, &it.Amount); err != nil {
			return nil, err
		}
		e.Items = append(e.Items, it)
	}
	return &e, rows.Err()
}

// SetEstimateStatus records the customer's decision — "approved" lets the
// technician proceed with the paid repair, "declined" ends it there. There
// is deliberately no separate status for "discuss": the technician just
// calls UpsertEstimate again with revised items, which resets status back
// to pending.
func (r *BookingRepository) SetEstimateStatus(ctx context.Context, bookingID, status string) error {
	tag, err := r.db.Exec(ctx, `UPDATE booking_estimates SET status = $1, updated_at = now() WHERE booking_id = $2`, status, bookingID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("no estimate found for this booking")
	}
	return nil
}

// --- Before/after service photos ---

func (r *BookingRepository) AddServicePhoto(ctx context.Context, bookingID, photoURL, photoType string) (*models.BookingServicePhoto, error) {
	var p models.BookingServicePhoto
	p.BookingID = bookingID
	p.PhotoURL = photoURL
	p.PhotoType = photoType
	err := r.db.QueryRow(ctx, `
		INSERT INTO booking_service_photos (booking_id, photo_url, photo_type)
		VALUES ($1,$2,$3) RETURNING id, created_at
	`, bookingID, photoURL, photoType).Scan(&p.ID, &p.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *BookingRepository) ListServicePhotos(ctx context.Context, bookingID string) ([]models.BookingServicePhoto, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, booking_id, photo_url, photo_type, created_at
		FROM booking_service_photos WHERE booking_id = $1 ORDER BY created_at ASC
	`, bookingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.BookingServicePhoto
	for rows.Next() {
		var p models.BookingServicePhoto
		if err := rows.Scan(&p.ID, &p.BookingID, &p.PhotoURL, &p.PhotoType, &p.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}