-- Adds the remaining service categories from the customer-flow spec that
-- 002_seed_categories.sql didn't include (Refrigerator, Washing Machine,
-- RO Service, CCTV, Home Cleaning). Idempotent like the original seed —
-- safe to run even if some of these already exist.
INSERT INTO categories (name, description, base_price, is_active) VALUES
    ('Refrigerator',     'Fridge repair, cooling issues and servicing',        279, true),
    ('RO Service',       'Water purifier installation, service and repair',    199, true),
    ('CCTV',             'CCTV camera installation and repair',                399, true),
    ('Home Cleaning',    'Deep cleaning and sanitization for your home',       349, true)
ON CONFLICT (name) DO NOTHING;