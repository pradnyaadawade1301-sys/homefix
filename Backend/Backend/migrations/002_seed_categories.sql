-- Seed service categories shown on the home screen (Day 1 UI reference + task brief).
INSERT INTO categories (name, description, base_price, is_active) VALUES
    ('Electrician',       'Wiring, switches, fittings and electrical repairs', 199, true),
    ('Plumber',           'Leak fixes, pipe fitting and plumbing repairs',      179, true),
    ('AC Repair',         'AC servicing, gas refill and repairs',               299, true),
    ('Appliance Repair',  'Repair for washing machines, fridges and more',      249, true),
    ('Roofer',            'Roof repair, waterproofing and maintenance',         349, true),
    ('Carpenter',         'Furniture repair, fitting and woodwork',             199, true),
    ('Painter',           'Interior and exterior painting services',            299, true)
ON CONFLICT (name) DO NOTHING;
