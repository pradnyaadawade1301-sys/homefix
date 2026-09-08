ALTER TABLE consultations
    ADD COLUMN IF NOT EXISTS note TEXT,
    ADD COLUMN IF NOT EXISTS area VARCHAR(120),
    ADD COLUMN IF NOT EXISTS ai_diagnosis_session_id UUID REFERENCES ai_diagnosis_sessions(id);

CREATE INDEX IF NOT EXISTS idx_consultations_ai_diagnosis ON consultations(ai_diagnosis_session_id);