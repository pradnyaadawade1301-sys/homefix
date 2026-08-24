-- Adds the modules needed for a production admin panel: disputes, spare-parts
-- inventory, CMS content, and an audit log of admin actions. None of this is
-- reachable from the Flutter app — only from the hidden /admin web panel (see
-- internal/admin), guarded by the existing role='admin' JWT/session check.

-- ---- Disputes ----

CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    consultation_id UUID REFERENCES consultations(id) ON DELETE CASCADE,
    raised_by UUID NOT NULL REFERENCES users(id),
    reason TEXT NOT NULL,
    -- open -> under_review -> resolved_refund | resolved_rejected | resolved_partial
    status VARCHAR(30) NOT NULL DEFAULT 'open',
    refund_amount NUMERIC(10,2),
    admin_notes TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT disputes_one_subject_chk CHECK ((booking_id IS NOT NULL)::int + (consultation_id IS NOT NULL)::int = 1)
);

CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_booking ON disputes(booking_id);

CREATE TABLE IF NOT EXISTS dispute_evidence (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dispute_id UUID NOT NULL REFERENCES disputes(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id),
    file_url TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Spare parts inventory ----

CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(150),
    phone VARCHAR(20),
    email VARCHAR(150),
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS spare_parts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES categories(id),
    supplier_id UUID REFERENCES suppliers(id),
    name VARCHAR(150) NOT NULL,
    sku VARCHAR(60) UNIQUE,
    description TEXT,
    unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    stock_quantity INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 5,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_spare_parts_category ON spare_parts(category_id);

-- Every stock change (restock, usage on a job, manual adjustment) is logged here
-- rather than only mutating spare_parts.stock_quantity, so usage can be audited.
CREATE TABLE IF NOT EXISTS spare_part_stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spare_part_id UUID NOT NULL REFERENCES spare_parts(id) ON DELETE CASCADE,
    change_type VARCHAR(20) NOT NULL, -- restock | usage | adjustment
    quantity_delta INT NOT NULL,      -- positive for restock, negative for usage
    booking_id UUID REFERENCES bookings(id),
    note TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS spare_part_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spare_part_id UUID NOT NULL REFERENCES spare_parts(id),
    supplier_id UUID REFERENCES suppliers(id),
    quantity INT NOT NULL,
    unit_cost NUMERIC(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ordered', -- ordered | received | cancelled
    ordered_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    received_at TIMESTAMPTZ
);

-- ---- CMS ----

-- Single-instance-per-key content pages (About Us, Privacy Policy, Terms, Help
-- Center) — one row per `key`, editable from the admin panel, publicly readable.
CREATE TABLE IF NOT EXISTS cms_pages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(50) UNIQUE NOT NULL, -- about_us | privacy_policy | terms_conditions | help_center
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cms_faqs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cms_announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cms_banners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200),
    image_url TEXT NOT NULL,
    link_url TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Audit log ----

-- Every mutating action taken from the admin panel — who, what, on which record,
-- and (best-effort) what changed. Never written to from the Flutter app's own API.
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR(100) NOT NULL,       -- e.g. "technician.approve", "dispute.resolve"
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100),
    details JSONB,
    ip_address VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_admin ON audit_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
