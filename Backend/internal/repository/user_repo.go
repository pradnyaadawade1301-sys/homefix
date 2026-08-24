package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"homefix-backend/internal/models"
)

type UserRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) CreateWithPhone(ctx context.Context, phone string) (*models.User, error) {
	var u models.User
	err := r.db.QueryRow(ctx, `
		INSERT INTO users (phone, role, phone_verified)
		VALUES ($1, 'customer', false)
		RETURNING id, phone, COALESCE(name,''), email, role, phone_verified, is_active, created_at, updated_at
	`, phone).Scan(&u.ID, &u.Phone, &u.Name, &u.Email, &u.Role, &u.PhoneVerified, &u.IsActive, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// CreateFull registers a user with name/email/phone/password in one step (used by the
// email+password signup flow, as opposed to CreateWithPhone which backs the OTP flow).
func (r *UserRepository) CreateFull(ctx context.Context, name, email, phone, passwordHash, role string) (*models.User, error) {
	var u models.User
	var emailArg interface{}
	if email != "" {
		emailArg = email
	}
	err := r.db.QueryRow(ctx, `
		INSERT INTO users (name, email, phone, password_hash, role, phone_verified)
		VALUES ($1, $2, $3, $4, $5, false)
		RETURNING id, phone, COALESCE(name,''), email, role, phone_verified, is_active, created_at, updated_at
	`, name, emailArg, phone, passwordHash, role).Scan(
		&u.ID, &u.Phone, &u.Name, &u.Email, &u.Role, &u.PhoneVerified, &u.IsActive, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// GetByIdentifier looks a user up by email or phone, whichever the login identifier looks like.
func (r *UserRepository) GetByIdentifier(ctx context.Context, identifier string) (*models.User, error) {
	var u models.User
	err := r.db.QueryRow(ctx, `
		SELECT id, phone, COALESCE(name,''), email, COALESCE(password_hash,''), role,
		       otp_code, otp_expires_at, phone_verified, fcm_token, is_active, created_at, updated_at
		FROM users WHERE email = $1 OR phone = $1
	`, identifier).Scan(&u.ID, &u.Phone, &u.Name, &u.Email, &u.PasswordHash, &u.Role,
		&u.OTPCode, &u.OTPExpiresAt, &u.PhoneVerified, &u.FCMToken, &u.IsActive, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &u, nil
}

// ExistsByEmailOrPhone checks for a pre-existing account so signup can return a clean error
// instead of a raw unique-constraint violation.
func (r *UserRepository) ExistsByEmailOrPhone(ctx context.Context, email, phone string) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1 OR (email IS NOT NULL AND email = $2))
	`, phone, email).Scan(&exists)
	return exists, err
}

func (r *UserRepository) GetByPhone(ctx context.Context, phone string) (*models.User, error) {
	var u models.User
	err := r.db.QueryRow(ctx, `
		SELECT id, phone, COALESCE(name,''), email, COALESCE(password_hash,''), role,
		       otp_code, otp_expires_at, phone_verified, fcm_token, is_active, created_at, updated_at
		FROM users WHERE phone = $1
	`, phone).Scan(&u.ID, &u.Phone, &u.Name, &u.Email, &u.PasswordHash, &u.Role,
		&u.OTPCode, &u.OTPExpiresAt, &u.PhoneVerified, &u.FCMToken, &u.IsActive, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) GetByID(ctx context.Context, id string) (*models.User, error) {
	var u models.User
	err := r.db.QueryRow(ctx, `
		SELECT id, phone, COALESCE(name,''), email, COALESCE(password_hash,''), role,
		       phone_verified, fcm_token, is_active, created_at, updated_at
		FROM users WHERE id = $1
	`, id).Scan(&u.ID, &u.Phone, &u.Name, &u.Email, &u.PasswordHash, &u.Role,
		&u.PhoneVerified, &u.FCMToken, &u.IsActive, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) SetOTP(ctx context.Context, userID, otp string, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET otp_code = $1, otp_expires_at = $2, updated_at = now() WHERE id = $3`,
		otp, expiresAt, userID)
	return err
}

func (r *UserRepository) VerifyOTPAndActivate(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE users SET phone_verified = true, otp_code = NULL, otp_expires_at = NULL, updated_at = now()
		WHERE id = $1
	`, userID)
	return err
}

func (r *UserRepository) UpdateProfile(ctx context.Context, userID, name string, email *string) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET name = $1, email = $2, updated_at = now() WHERE id = $3`,
		name, email, userID)
	return err
}

func (r *UserRepository) SetPasswordHash(ctx context.Context, userID, hash string) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2`, hash, userID)
	return err
}

func (r *UserRepository) SetFCMToken(ctx context.Context, userID, token string) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET fcm_token = $1, updated_at = now() WHERE id = $2`, token, userID)
	return err
}

// --- Admin panel (internal/admin) only, below ---

// ListAll powers the admin panel's User Management screen. role == "" lists every role.
func (r *UserRepository) ListAll(ctx context.Context, role string) ([]models.User, error) {
	query := `SELECT id, phone, COALESCE(name,''), email, '', role, phone_verified, fcm_token, is_active, created_at, updated_at FROM users`
	args := []interface{}{}
	if role != "" {
		query += ` WHERE role = $1`
		args = append(args, role)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.User
	for rows.Next() {
		var u models.User
		if err := rows.Scan(&u.ID, &u.Phone, &u.Name, &u.Email, &u.PasswordHash, &u.Role,
			&u.PhoneVerified, &u.FCMToken, &u.IsActive, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// SetActive suspends/reinstates a user account — the admin panel's ban/unban action.
// Does not delete anything (bookings/history stay intact for audit purposes).
func (r *UserRepository) SetActive(ctx context.Context, userID string, active bool) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET is_active = $1, updated_at = now() WHERE id = $2`, active, userID)
	return err
}

// CreateAdmin creates an admin-role user directly — there is no public signup path
// for the admin role (see auth_handler.go's Signup, which only ever creates
// customer/technician). Used only by the seed script / an existing admin's own
// "add admin" action in the panel.
func (r *UserRepository) CreateAdmin(ctx context.Context, name, email, phone, passwordHash string) (*models.User, error) {
	return r.CreateFull(ctx, name, email, phone, passwordHash, "admin")
}

func (r *UserRepository) CreateAddress(ctx context.Context, a *models.Address) (*models.Address, error) {
	err := r.db.QueryRow(ctx, `
		INSERT INTO addresses (user_id, label, line1, line2, city, state, pincode, latitude, longitude, is_default)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		RETURNING id, created_at
	`, a.UserID, a.Label, a.Line1, a.Line2, a.City, a.State, a.Pincode, a.Latitude, a.Longitude, a.IsDefault,
	).Scan(&a.ID, &a.CreatedAt)
	if err != nil {
		return nil, err
	}
	return a, nil
}

func (r *UserRepository) ListAddresses(ctx context.Context, userID string) ([]models.Address, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, COALESCE(label,''), line1, COALESCE(line2,''), city, state, pincode,
		       latitude, longitude, is_default, created_at
		FROM addresses WHERE user_id = $1 ORDER BY is_default DESC, created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Address
	for rows.Next() {
		var a models.Address
		if err := rows.Scan(&a.ID, &a.UserID, &a.Label, &a.Line1, &a.Line2, &a.City, &a.State, &a.Pincode,
			&a.Latitude, &a.Longitude, &a.IsDefault, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, nil
}
