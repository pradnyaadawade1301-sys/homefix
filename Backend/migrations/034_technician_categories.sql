-- Lets one technician serve more than one category (e.g. Plumbing AND
-- Painting) instead of the single technicians.category_id column. That
-- column is kept as the technician's "primary" category (first one chosen,
-- used anywhere that still expects exactly one — admin queue, repeat-
-- customer cards, etc), while this table is the source of truth for
-- search/matching (see TechnicianRepository.ListPublic /
-- ListAvailableByCategory, which now join on it).
CREATE TABLE IF NOT EXISTS technician_categories (
    technician_id UUID NOT NULL REFERENCES technicians(id) ON DELETE CASCADE,
    category_id   UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (technician_id, category_id)
);

CREATE INDEX IF NOT EXISTS idx_technician_categories_category ON technician_categories (category_id);

-- Backfill: every existing technician's current single category becomes
-- their first (primary) entry here, so nobody drops out of search results
-- the moment this ships.
INSERT INTO technician_categories (technician_id, category_id)
SELECT id, category_id FROM technicians
ON CONFLICT (technician_id, category_id) DO NOTHING;