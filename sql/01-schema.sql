-- =============================================================================
-- Extensions
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Configure object-level auditing for the internal schema.
-- Session-level settings (ddl, role, write) are set in postgresql.conf via
-- the docker-compose command stanza; these ALTER ROLE settings layer on top.
ALTER ROLE postgres SET pgaudit.log = 'ddl, role, write';

-- =============================================================================
-- Roles (PostgREST)
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'web_anon') THEN
        CREATE ROLE web_anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'customer') THEN
        CREATE ROLE customer NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'staff') THEN
        CREATE ROLE staff NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authenticator_pass';
    END IF;
END $$;

GRANT web_anon TO authenticator;
GRANT customer TO authenticator;
GRANT staff    TO authenticator;

-- =============================================================================
-- Schemas
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS internal;

-- =============================================================================
-- Suburbs
-- =============================================================================
CREATE TABLE internal.suburbs (
    id       SERIAL PRIMARY KEY,
    name     TEXT NOT NULL UNIQUE,
    postcode TEXT NOT NULL,
    location GEOGRAPHY(GEOMETRY, 4326) NOT NULL  -- polygon boundary
);

CREATE INDEX suburbs_location_idx ON internal.suburbs USING GIST (location);

-- =============================================================================
-- Users
-- =============================================================================
CREATE TABLE internal.users (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT        NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL,
    first_name    TEXT        NOT NULL,
    last_name     TEXT        NOT NULL,
    suburb_id     INT         REFERENCES internal.suburbs (id),
    role          TEXT        NOT NULL DEFAULT 'customer'
                              CHECK (role IN ('customer', 'staff')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- Stores
-- =============================================================================
CREATE TABLE internal.stores (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT        NOT NULL,
    address    TEXT        NOT NULL,
    suburb_id  INT         NOT NULL REFERENCES internal.suburbs (id),
    location   GEOGRAPHY(POINT, 4326) NOT NULL,
    phone      TEXT,
    is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX stores_location_idx ON internal.stores USING GIST (location);

-- Opening hours: one row per store per day of week
-- day_of_week follows ISODOW: 1=Monday … 7=Sunday
CREATE TABLE internal.store_hours (
    id           SERIAL  PRIMARY KEY,
    store_id     UUID    NOT NULL REFERENCES internal.stores (id) ON DELETE CASCADE,
    day_of_week  SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    open_time    TIME    NOT NULL,
    close_time   TIME    NOT NULL,
    is_closed    BOOLEAN NOT NULL DEFAULT FALSE,  -- TRUE on public holidays / days off
    UNIQUE (store_id, day_of_week)
);

-- =============================================================================
-- Menu
-- =============================================================================
CREATE TABLE internal.menu_categories (
    id           SERIAL PRIMARY KEY,
    name         TEXT   NOT NULL UNIQUE,
    display_name TEXT   NOT NULL
);

CREATE TABLE internal.pizza_sizes (
    id           SERIAL   PRIMARY KEY,
    name         TEXT     NOT NULL UNIQUE,
    diameter_cm  SMALLINT NOT NULL
);

CREATE TABLE internal.pizza_bases (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL UNIQUE
);

CREATE TABLE internal.menu_items (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id   INT          NOT NULL REFERENCES internal.menu_categories (id),
    name          TEXT         NOT NULL,
    description   TEXT,
    base_price    NUMERIC(8,2) NOT NULL CHECK (base_price >= 0),
    is_available  BOOLEAN      NOT NULL DEFAULT TRUE,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector('english', name), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'B')
    ) STORED,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX menu_items_search_idx ON internal.menu_items USING GIN (search_vector);
CREATE INDEX menu_items_trgm_idx   ON internal.menu_items USING GIN (name gin_trgm_ops);

-- Pizza variants: size + base combos with their own price
CREATE TABLE internal.menu_item_variants (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID         NOT NULL REFERENCES internal.menu_items (id) ON DELETE CASCADE,
    size_id      INT          NOT NULL REFERENCES internal.pizza_sizes (id),
    base_id      INT          NOT NULL REFERENCES internal.pizza_bases (id),
    price        NUMERIC(8,2) NOT NULL CHECK (price >= 0),
    UNIQUE (menu_item_id, size_id, base_id)
);

-- =============================================================================
-- Orders
-- =============================================================================
CREATE TYPE internal.order_status AS ENUM ('pending', 'processing', 'processed', 'cancelled');

CREATE TABLE internal.orders (
    id               UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID                  NOT NULL REFERENCES internal.users (id),
    store_id         UUID                  NOT NULL REFERENCES internal.stores (id),
    status           internal.order_status NOT NULL DEFAULT 'pending',
    delivery_address TEXT,
    total_amount     NUMERIC(10,2)         NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    notes            TEXT,
    search_vector    TSVECTOR,
    created_at       TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE INDEX orders_queue_idx  ON internal.orders (store_id, created_at)
    WHERE status IN ('pending', 'processing');
CREATE INDEX orders_user_idx   ON internal.orders (user_id);
CREATE INDEX orders_search_idx ON internal.orders USING GIN (search_vector);

CREATE TABLE internal.order_items (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id   UUID         NOT NULL REFERENCES internal.orders (id) ON DELETE CASCADE,
    item_id    UUID         NOT NULL REFERENCES internal.menu_items (id),
    variant_id UUID         REFERENCES internal.menu_item_variants (id),
    quantity   SMALLINT     NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price NUMERIC(8,2) NOT NULL CHECK (unit_price >= 0),
    notes      TEXT
);

-- =============================================================================
-- Auth event log
-- Tracks signup and login attempts. Partitioned by month.
-- =============================================================================
CREATE TABLE internal.auth_log (
    id          BIGSERIAL   NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type  TEXT        NOT NULL CHECK (event_type IN ('signup', 'login_success', 'login_failure')),
    email       TEXT        NOT NULL,
    user_id     UUID,
    ip_addr     INET        DEFAULT inet_client_addr(),
    details     JSONB
) PARTITION BY RANGE (occurred_at);

-- =============================================================================
-- Audit log table
-- pgaudit handles statement-level DDL/DML logging to pg_log.
-- This table adds row-level change capture for sensitive tables,
-- with BRIN indexes on timestamps (append-only, written in time order).
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
-- Monthly partitions (current + 3 months ahead) for both partitioned tables.
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
-- Triggers
-- =============================================================================
CREATE OR REPLACE FUNCTION internal.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END $$;

CREATE TRIGGER orders_updated_at
    BEFORE UPDATE ON internal.orders
    FOR EACH ROW EXECUTE FUNCTION internal.set_updated_at();

CREATE OR REPLACE FUNCTION internal.refresh_order_search_vector()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_order_id UUID;
BEGIN
    v_order_id := COALESCE(NEW.order_id, OLD.order_id);
    UPDATE internal.orders o
    SET search_vector = (
        SELECT setweight(to_tsvector('english', string_agg(mi.name, ' ')), 'A')
        FROM   internal.order_items oi
        JOIN   internal.menu_items  mi ON mi.id = oi.item_id
        WHERE  oi.order_id = v_order_id
    )
    WHERE o.id = v_order_id;
    RETURN NULL;
END $$;

CREATE TRIGGER order_items_search_sync
    AFTER INSERT OR UPDATE OR DELETE ON internal.order_items
    FOR EACH ROW EXECUTE FUNCTION internal.refresh_order_search_vector();

-- =============================================================================
-- Audit trigger function — attached to each audited table
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

-- Attach audit trigger to sensitive tables
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
-- Helper functions
-- =============================================================================

-- Convenience function: is a given store open right now?
CREATE OR REPLACE FUNCTION internal.is_store_open(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   internal.store_hours
        WHERE  store_id    = p_store_id
        AND    day_of_week = EXTRACT(ISODOW FROM NOW() AT TIME ZONE 'Australia/Sydney')::SMALLINT
        AND    is_closed   = FALSE
        AND    open_time  <= (NOW() AT TIME ZONE 'Australia/Sydney')::TIME
        AND    close_time >= (NOW() AT TIME ZONE 'Australia/Sydney')::TIME
    );
$$;

-- Queue: claim next pending order with SKIP LOCKED
CREATE OR REPLACE FUNCTION internal.claim_next_order(p_store_id UUID)
RETURNS SETOF internal.orders LANGUAGE sql AS $$
    UPDATE internal.orders
    SET    status = 'processing', updated_at = NOW()
    WHERE  id = (
        SELECT id FROM internal.orders
        WHERE  store_id = p_store_id
        AND    status   = 'pending'
        ORDER  BY created_at
        LIMIT  1
        FOR UPDATE SKIP LOCKED
    )
    RETURNING *;
$$;

-- Authentication helper
CREATE OR REPLACE FUNCTION internal.authenticate(p_email TEXT, p_password TEXT)
RETURNS TABLE (user_id UUID, role TEXT) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT id, u.role
    FROM   internal.users u
    WHERE  email = p_email
    AND    password_hash = crypt(p_password, password_hash);
END $$;

-- PostGIS: nearest stores to a suburb name
CREATE OR REPLACE FUNCTION internal.stores_near_suburb(p_suburb TEXT, p_limit INT DEFAULT 5)
RETURNS TABLE (store_id UUID, store_name TEXT, address TEXT, distance_m FLOAT)
LANGUAGE sql STABLE AS $$
    SELECT  s.id,
            s.name,
            s.address,
            ST_Distance(s.location, ST_Centroid(sub.location::geometry)::geography) AS distance_m
    FROM    internal.stores s
    CROSS JOIN LATERAL (
        SELECT location FROM internal.suburbs
        WHERE  lower(name) = lower(p_suburb)
        LIMIT  1
    ) sub
    WHERE   s.is_active
    ORDER   BY distance_m
    LIMIT   p_limit;
$$;

-- JWT helpers (uses pgcrypto hmac — no extra extension needed)
CREATE OR REPLACE FUNCTION internal.base64url_encode(data BYTEA)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    -- Standard base64, then make URL-safe and strip = padding
    SELECT rtrim(
        replace(replace(replace(encode(data, 'base64'), E'\n', ''), '+', '-'), '/', '_'),
        '='
    );
$$;

CREATE OR REPLACE FUNCTION internal.jwt_sign(p_payload JSON)
RETURNS TEXT LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
    v_header TEXT := internal.base64url_encode('{"alg":"HS256","typ":"JWT"}'::BYTEA);
    v_body   TEXT := internal.base64url_encode(p_payload::TEXT::BYTEA);
    v_secret TEXT := current_setting('app.settings.jwt_secret');
BEGIN
    RETURN v_header || '.' || v_body || '.' ||
           internal.base64url_encode(hmac(v_header || '.' || v_body, v_secret, 'sha256'));
END;
$$;

-- Partition maintenance helper (call monthly via pg_cron or external scheduler)
-- Creates next month's partitions for audit_log and auth_log if they don't exist.
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

-- =============================================================================
-- API schema
-- =============================================================================
CREATE OR REPLACE VIEW api.menu AS
    SELECT  mi.id,
            mc.name        AS category,
            mi.name,
            mi.description,
            mi.base_price,
            mi.is_available
    FROM    internal.menu_items      mi
    JOIN    internal.menu_categories mc ON mc.id = mi.category_id
    WHERE   mi.is_available;

CREATE OR REPLACE VIEW api.menu_variants AS
    SELECT  v.id,
            v.menu_item_id,
            ps.name AS size,
            pb.name AS base,
            v.price
    FROM    internal.menu_item_variants v
    JOIN    internal.pizza_sizes        ps ON ps.id = v.size_id
    JOIN    internal.pizza_bases        pb ON pb.id = v.base_id;

CREATE OR REPLACE VIEW api.stores AS
    SELECT  s.id,
            s.name,
            s.address,
            sub.name     AS suburb,
            sub.postcode,
            s.phone,
            s.is_active,
            internal.is_store_open(s.id) AS is_open_now,
            ST_Y(s.location::geometry)   AS latitude,
            ST_X(s.location::geometry)   AS longitude
    FROM    internal.stores  s
    JOIN    internal.suburbs sub ON sub.id = s.suburb_id;

-- Suburb boundaries as GeoJSON for the Leaflet map
CREATE OR REPLACE VIEW api.suburbs AS
    SELECT
        id,
        name,
        postcode,
        ST_AsGeoJSON(location)::json AS boundary,
        ST_AsGeoJSON(ST_Centroid(location::geometry))::json AS centroid
    FROM internal.suburbs;

CREATE OR REPLACE VIEW api.store_hours AS
    SELECT  sh.store_id,
            s.name   AS store_name,
            sh.day_of_week,
            TO_CHAR(sh.open_time,  'HH24:MI') AS opens,
            TO_CHAR(sh.close_time, 'HH24:MI') AS closes,
            sh.is_closed
    FROM    internal.store_hours sh
    JOIN    internal.stores      s ON s.id = sh.store_id
    ORDER   BY sh.store_id, sh.day_of_week;

CREATE OR REPLACE VIEW api.orders AS
    SELECT  id, store_id, status, delivery_address,
            total_amount, notes, created_at, updated_at
    FROM    internal.orders;

CREATE OR REPLACE VIEW api.order_items AS
    SELECT  oi.id, oi.order_id, oi.item_id, oi.variant_id,
            oi.quantity, oi.unit_price, oi.notes
    FROM    internal.order_items oi
    JOIN    internal.orders      o  ON o.id = oi.order_id;

-- API views for audit access (staff only)
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

-- Full-text + trigram menu search
CREATE OR REPLACE FUNCTION api.search_menu(q TEXT)
RETURNS SETOF api.menu LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT m.*
    FROM   api.menu m
    JOIN   internal.menu_items mi ON mi.id = m.id
    WHERE  mi.search_vector @@ websearch_to_tsquery('english', q)
       OR  mi.name ILIKE '%' || q || '%'
    ORDER  BY ts_rank(mi.search_vector, websearch_to_tsquery('english', q)) DESC;
$$;

-- Stores near a suburb
CREATE OR REPLACE FUNCTION api.stores_near(suburb TEXT, lim INT DEFAULT 5)
RETURNS TABLE (store_id UUID, store_name TEXT, address TEXT, distance_m FLOAT)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT * FROM internal.stores_near_suburb(suburb, lim);
$$;

-- Place an order
CREATE OR REPLACE FUNCTION api.place_order(
    p_store_id         UUID,
    p_delivery_address TEXT,
    p_items            JSONB  -- [{item_id, variant_id?, quantity, notes?}]
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id  UUID := (current_setting('request.jwt.claims', true)::json->>'sub')::UUID;
    v_order_id UUID;
    v_total    NUMERIC(10,2) := 0;
    v_item     JSONB;
    v_price    NUMERIC(8,2);
BEGIN
    INSERT INTO internal.orders (user_id, store_id, delivery_address)
    VALUES (v_user_id, p_store_id, p_delivery_address)
    RETURNING id INTO v_order_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        IF v_item->>'variant_id' IS NOT NULL THEN
            SELECT price INTO v_price FROM internal.menu_item_variants
            WHERE id = (v_item->>'variant_id')::UUID;
        ELSE
            SELECT base_price INTO v_price FROM internal.menu_items
            WHERE id = (v_item->>'item_id')::UUID;
        END IF;

        INSERT INTO internal.order_items
            (order_id, item_id, variant_id, quantity, unit_price, notes)
        VALUES (
            v_order_id,
            (v_item->>'item_id')::UUID,
            (v_item->>'variant_id')::UUID,
            COALESCE((v_item->>'quantity')::SMALLINT, 1),
            v_price,
            v_item->>'notes'
        );

        v_total := v_total + v_price * COALESCE((v_item->>'quantity')::SMALLINT, 1);
    END LOOP;

    UPDATE internal.orders SET total_amount = v_total WHERE id = v_order_id;
    RETURN v_order_id;
END $$;

-- Staff: claim next order (SKIP LOCKED)
CREATE OR REPLACE FUNCTION api.claim_next_order(p_store_id UUID)
RETURNS SETOF api.orders LANGUAGE sql SECURITY DEFINER AS $$
    SELECT id, store_id, status, delivery_address, total_amount, notes, created_at, updated_at
    FROM   internal.claim_next_order(p_store_id);
$$;

-- Staff: mark order processed
CREATE OR REPLACE FUNCTION api.complete_order(p_order_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
    UPDATE internal.orders
    SET    status = 'processed'
    WHERE  id     = p_order_id AND status = 'processing';
$$;

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

-- =============================================================================
-- api.signup
-- =============================================================================
CREATE OR REPLACE FUNCTION api.signup(
    p_email      TEXT,
    p_password   TEXT,
    p_first_name TEXT,
    p_last_name  TEXT,
    p_suburb     TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id   UUID;
    v_suburb_id INT;
BEGIN
    IF p_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'Invalid email address' USING ERRCODE = 'P0001';
    END IF;

    IF char_length(p_password) < 8 THEN
        RAISE EXCEPTION 'Password must be at least 8 characters' USING ERRCODE = 'P0001';
    END IF;

    IF p_suburb IS NOT NULL THEN
        SELECT id INTO v_suburb_id
        FROM   internal.suburbs
        WHERE  lower(name) = lower(p_suburb);
    END IF;

    INSERT INTO internal.users (email, password_hash, first_name, last_name, suburb_id)
    VALUES (
        lower(trim(p_email)),
        crypt(p_password, gen_salt('bf', 8)),  -- bcrypt cost 8
        p_first_name,
        p_last_name,
        v_suburb_id
    )
    RETURNING id INTO v_user_id;

    INSERT INTO internal.auth_log (event_type, email, user_id)
    VALUES ('signup', lower(trim(p_email)), v_user_id);

    RETURN json_build_object(
        'token',   internal.jwt_sign(json_build_object(
            'role', 'customer',
            'sub',  v_user_id,
            'exp',  extract(epoch FROM now() + interval '24 hours')::bigint
        )),
        'user_id', v_user_id
    );

EXCEPTION
    WHEN unique_violation THEN
        INSERT INTO internal.auth_log (event_type, email, details)
        VALUES ('signup', lower(trim(p_email)), '{"error":"email_taken"}'::JSONB);
        RAISE EXCEPTION 'Email already registered' USING ERRCODE = 'P0002';
END;
$$;

-- =============================================================================
-- api.login
-- =============================================================================
CREATE OR REPLACE FUNCTION api.login(
    p_email    TEXT,
    p_password TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user internal.users;
BEGIN
    SELECT * INTO v_user
    FROM   internal.users
    WHERE  email         = lower(trim(p_email))
    AND    password_hash = crypt(p_password, password_hash);

    IF NOT FOUND THEN
        -- Generic error message prevents email enumeration
        INSERT INTO internal.auth_log (event_type, email, details)
        VALUES ('login_failure', lower(trim(p_email)), '{"error":"invalid_credentials"}'::JSONB);
        RAISE EXCEPTION 'Invalid email or password' USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO internal.auth_log (event_type, email, user_id)
    VALUES ('login_success', v_user.email, v_user.id);

    RETURN json_build_object(
        'token',   internal.jwt_sign(json_build_object(
            'role', v_user.role,
            'sub',  v_user.id,
            'exp',  extract(epoch FROM now() + interval '24 hours')::bigint
        )),
        'user_id', v_user.id,
        'role',    v_user.role
    );
END;
$$;

-- =============================================================================
-- Row-Level Security
-- =============================================================================
ALTER TABLE internal.users       ENABLE ROW LEVEL SECURITY;
ALTER TABLE internal.orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE internal.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_self ON internal.users
    USING (id = (current_setting('request.jwt.claims', true)::json->>'sub')::UUID);

CREATE POLICY orders_customer ON internal.orders FOR ALL TO customer
    USING (user_id = (current_setting('request.jwt.claims', true)::json->>'sub')::UUID);

CREATE POLICY orders_staff ON internal.orders FOR ALL TO staff
    USING (TRUE);

CREATE POLICY order_items_customer ON internal.order_items FOR ALL TO customer
    USING (order_id IN (
        SELECT id FROM internal.orders
        WHERE user_id = (current_setting('request.jwt.claims', true)::json->>'sub')::UUID
    ));

CREATE POLICY order_items_staff ON internal.order_items FOR ALL TO staff
    USING (TRUE);

-- =============================================================================
-- Grants
-- =============================================================================
GRANT USAGE ON SCHEMA api      TO web_anon, customer, staff;
GRANT USAGE ON SCHEMA internal TO authenticator, staff;

GRANT SELECT   ON api.menu          TO web_anon, customer, staff;
GRANT SELECT   ON api.menu_variants TO web_anon, customer, staff;
GRANT SELECT   ON api.stores        TO web_anon, customer, staff;
GRANT SELECT   ON api.store_hours   TO web_anon, customer, staff;
GRANT SELECT   ON api.suburbs       TO web_anon, customer, staff;
GRANT SELECT   ON api.orders        TO customer, staff;
GRANT SELECT   ON api.order_items   TO customer, staff;
GRANT SELECT   ON api.audit_log     TO staff;
GRANT SELECT   ON api.auth_log      TO staff;

GRANT EXECUTE ON FUNCTION api.search_menu(TEXT)                  TO web_anon, customer, staff;
GRANT EXECUTE ON FUNCTION api.stores_near(TEXT, INT)             TO web_anon, customer, staff;
GRANT EXECUTE ON FUNCTION api.place_order(UUID, TEXT, JSONB)     TO customer;
GRANT EXECUTE ON FUNCTION api.claim_next_order(UUID)             TO staff;
GRANT EXECUTE ON FUNCTION api.complete_order(UUID)               TO staff;
GRANT EXECUTE ON FUNCTION api.order_audit(UUID)                  TO staff;
GRANT EXECUTE ON FUNCTION api.signup(TEXT, TEXT, TEXT, TEXT, TEXT) TO web_anon;
GRANT EXECUTE ON FUNCTION api.login(TEXT, TEXT)                    TO web_anon;
