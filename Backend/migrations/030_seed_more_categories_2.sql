-- Adds 4 more service categories requested by the client, matching the
-- pattern from 002_seed_categories.sql / 004_seed_more_categories.sql.
-- ON CONFLICT (name) DO NOTHING keeps this safe to re-run (see Makefile's
-- `migrate` target, which re-applies every migrations/*.sql file every time).
INSERT INTO categories (name, description, is_active) VALUES
    ('Civil Work',           'Masonry, tiling, and construction work',        true),
    ('Fabrication',          'Metal fabrication and welding work',            true),
    ('POP / False Ceiling',  'POP work and false ceiling installation',       true),
    ('General Repair',       'General home repair and maintenance',           true)
ON CONFLICT (name) DO NOTHING;