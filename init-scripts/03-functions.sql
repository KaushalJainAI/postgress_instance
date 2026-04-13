-- ============================================================
-- 03 — Helper Functions
-- ============================================================
-- Reusable utility functions available to all projects.
-- ============================================================

-- Auto-update 'updated_at' column on row modification
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Convenience: create an updated_at trigger on any table
-- Usage: SELECT create_updated_at_trigger('my_table');
CREATE OR REPLACE FUNCTION create_updated_at_trigger(target_table TEXT)
RETURNS VOID AS $$
BEGIN
    EXECUTE format(
        'CREATE TRIGGER set_updated_at
         BEFORE UPDATE ON %I
         FOR EACH ROW
         EXECUTE FUNCTION trigger_set_updated_at()',
        target_table
    );
END;
$$ LANGUAGE plpgsql;

-- Generate a short, URL-safe ID (useful for public-facing IDs)
CREATE OR REPLACE FUNCTION generate_short_id(length INTEGER DEFAULT 12)
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..length LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;
