-- =============================================================================
-- Audit logging
-- pgaudit handles statement-level DDL/DML logging to pg_log.
-- This file adds a row-level audit table for data changes on sensitive tables,
-- with BRIN indexes on timestamps (audit logs are append-only and written in
-- time order, so BRIN is far cheaper than B-tree at scale).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Configure object-level auditing for the internal schema.
-- Session-level settings (ddl, role, write) are set in postgresql.conf via
-- the docker-compose command stanza; these ALTER ROLE settings layer on top.
ALTER ROLE postgres SET pgaudit.log = 'ddl, role, write';

-- =============================================================================
-- Audit log table
-- =============================================================================
CREATE TABLE internal.audit_log (
    id           BIGSERIAL    NOT NULL,
    occurred_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    -- Who
    db_user      TEXT         NOT NULL DEFAULT current_user,
    app_user_id  UUID,                          -- JWT sub when available
    app_role     TEXT,                          -- JWT role when available
    client_addr  INET         DEFAULT inet_client_addr(),
    -- What
    schema_name  TEXT         NOT NULL,
    table_name   TEXT         NOT NULL,
    operation    TEXT         NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE','TRUNCATE')),
    -- Data snapshot
    old_data     JSONB,                         -- NULL for INSERT
    new_data     JSONB,                         -- NULL for DELETE
    changed_cols TEXT[],                        -- populated on UPDATE only
    -- Statement context
    query_text   TEXT,
    txid         BIGINT       NOT NULL DEFAULT txid_current()
) PARTITION BY RANGE (occurred_at);

-- =============================================================================
-- Default monthly partitions (current + 3 months ahead)
-- In production, use pg_partman to auto-create future partitions.
-- Indexes are created AFTER this block so an index failure cannot prevent
-- partition creation.
-- =============================================================================
DO $$
DECLARE
    start_date DATE := DATE_TRUNC('month', NOW());
    i          INT;
    p_start    DATE;
    p_end      DATE;
    p_name     TEXT;
BEGIN
    FOR i IN 0..3 LOOP
        p_start := start_date + (i || ' months')::INTERVAL;
        p_end   := p_start   + '1 month'::INTERVAL;

        -- audit_log partitions
        p_name := 'audit_log_' || TO_CHAR(p_start, 'YYYY_MM');
        IF NOT EXISTS (
            SELECT FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'internal' AND c.relname = p_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE internal.%I PARTITION OF internal.audit_log
                 FOR VALUES FROM (%L) TO (%L)',
                p_name, p_start, p_end
            );
        END IF;

        -- auth_log partitions
        p_name := 'auth_log_' || TO_CHAR(p_start, 'YYYY_MM');
        IF NOT EXISTS (
            SELECT FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'internal' AND c.relname = p_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE internal.%I PARTITION OF internal.auth_log
                 FOR VALUES FROM (%L) TO (%L)',
                p_name, p_start, p_end
            );
        END IF;
    END LOOP;
END $$;

-- =============================================================================
-- Indexes — created after partitions so failures here don't block partition setup
-- =============================================================================

-- audit_log: BRIN on timestamp (naturally ordered — ideal for BRIN)
CREATE INDEX audit_log_occurred_at_brin
    ON internal.audit_log USING BRIN (occurred_at)
    WITH (pages_per_range = 128);

-- audit_log: B-tree on UUID and text columns (not naturally ordered, BRIN unsuitable)
CREATE INDEX audit_log_app_user_idx   ON internal.audit_log (app_user_id);
CREATE INDEX audit_log_table_op_idx   ON internal.audit_log (table_name, operation);

-- auth_log: BRIN on timestamp
CREATE INDEX auth_log_occurred_at_brin
    ON internal.auth_log USING BRIN (occurred_at)
    WITH (pages_per_range = 128);

-- auth_log: B-tree on UUID and event_type
CREATE INDEX auth_log_user_idx        ON internal.auth_log (user_id);
CREATE INDEX auth_log_event_type_idx  ON internal.auth_log (event_type);

-- =============================================================================
-- Generic trigger function — attached to each audited table
-- =============================================================================
CREATE OR REPLACE FUNCTION internal.audit_trigger()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_old        JSONB;
    v_new        JSONB;
    v_changed    TEXT[];
    v_app_user   UUID;
    v_app_role   TEXT;
    v_claims     JSON;
BEGIN
    -- Extract JWT claims if PostgREST has set them
    BEGIN
        v_claims    := current_setting('request.jwt.claims', true)::JSON;
        v_app_user  := (v_claims->>'sub')::UUID;
        v_app_role  := v_claims->>'role';
    EXCEPTION WHEN OTHERS THEN
        -- Not running under PostgREST (e.g. direct psql); leave NULL
    END;

    IF TG_OP = 'INSERT' THEN
        v_new := to_jsonb(NEW);

    ELSIF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD);
        v_new := to_jsonb(NEW);
        -- Record only the columns that actually changed
        SELECT ARRAY_AGG(key)
        INTO   v_changed
        FROM   jsonb_each(v_old) o
        WHERE  o.value IS DISTINCT FROM v_new->o.key;

    ELSIF TG_OP IN ('DELETE', 'TRUNCATE') THEN
        v_old := to_jsonb(OLD);
    END IF;

    -- Scrub sensitive fields before storing
    v_old := v_old - 'password_hash';
    v_new := v_new - 'password_hash';

    INSERT INTO internal.audit_log
        (schema_name, table_name, operation,
         app_user_id, app_role,
         old_data, new_data, changed_cols,
         query_text)
    VALUES (
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP,
        v_app_user, v_app_role,
        v_old, v_new, v_changed,
        current_query()
    );

    RETURN NULL;  -- AFTER trigger; return value is ignored
END $$;

-- =============================================================================
-- Attach audit trigger to sensitive tables
-- =============================================================================
CREATE TRIGGER audit_users
    AFTER INSERT OR UPDATE OR DELETE ON internal.users
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger();

CREATE TRIGGER audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON internal.orders
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger();

CREATE TRIGGER audit_order_items
    AFTER INSERT OR UPDATE OR DELETE ON internal.order_items
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger();

CREATE TRIGGER audit_menu_items
    AFTER INSERT OR UPDATE OR DELETE ON internal.menu_items
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger();

CREATE TRIGGER audit_stores
    AFTER INSERT OR UPDATE OR DELETE ON internal.stores
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger();

-- =============================================================================
-- API views for audit access (staff only)
-- =============================================================================
CREATE OR REPLACE VIEW api.audit_log AS
    SELECT
        id,
        occurred_at,
        db_user,
        app_user_id,
        app_role,
        schema_name,
        table_name,
        operation,
        old_data,
        new_data,
        changed_cols,
        txid
    FROM internal.audit_log
    ORDER BY occurred_at DESC;

-- Convenience: audit history for a single order
CREATE OR REPLACE FUNCTION api.order_audit(p_order_id UUID)
RETURNS SETOF api.audit_log LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT *
    FROM   api.audit_log
    WHERE  table_name = 'orders'
    AND    (old_data->>'id' = p_order_id::TEXT
         OR new_data->>'id' = p_order_id::TEXT)
    ORDER  BY occurred_at;
$$;

GRANT SELECT   ON api.audit_log               TO staff;
GRANT EXECUTE ON FUNCTION api.order_audit(UUID) TO staff;

-- Auth event log — staff only
CREATE OR REPLACE VIEW api.auth_log AS
    SELECT
        id,
        occurred_at,
        event_type,
        email,
        user_id,
        ip_addr,
        details
    FROM internal.auth_log
    ORDER BY occurred_at DESC;

GRANT SELECT ON api.auth_log TO staff;

-- =============================================================================
-- Partition maintenance helper (call monthly via pg_cron or external scheduler)
-- Creates the next month's partition if it doesn't already exist.
-- =============================================================================
CREATE OR REPLACE FUNCTION internal.create_next_audit_partition()
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    p_start DATE := DATE_TRUNC('month', NOW() + INTERVAL '1 month');
    p_end   DATE := p_start + INTERVAL '1 month';
    p_name  TEXT;
BEGIN
    p_name := 'audit_log_' || TO_CHAR(p_start, 'YYYY_MM');
    IF NOT EXISTS (
        SELECT FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'internal' AND c.relname = p_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE internal.%I PARTITION OF internal.audit_log
             FOR VALUES FROM (%L) TO (%L)',
            p_name, p_start, p_end
        );
        RAISE NOTICE 'Created audit partition: %', p_name;
    END IF;

    p_name := 'auth_log_' || TO_CHAR(p_start, 'YYYY_MM');
    IF NOT EXISTS (
        SELECT FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'internal' AND c.relname = p_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE internal.%I PARTITION OF internal.auth_log
             FOR VALUES FROM (%L) TO (%L)',
            p_name, p_start, p_end
        );
        RAISE NOTICE 'Created auth_log partition: %', p_name;
    END IF;
END $$;
