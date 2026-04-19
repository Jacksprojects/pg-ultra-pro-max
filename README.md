# PostgreSQL Ultra Pro Max

A proof-of-concept app that uses PostgreSQL exclusively for all functionality — no application-layer, middleware or external services.
Just two html pages and postgres allows you to order pizzas with over 200 transactions per second.

## Features

- **REST API** — PostgREST exposes the `api` schema directly as a JSON REST API. No hand-written HTTP layer.
- **Order queue (SKIP LOCKED)** — Staff claim the next pending order atomically with `FOR UPDATE SKIP LOCKED`, preventing double-processing under concurrent load.
- **PostGIS nearest-store lookup** — `api.stores_near(suburb)` finds the closest stores to a suburb name using `ST_Distance` on `GEOGRAPHY(POINT, 4326)` columns.
- **Full-text search** — `TSVECTOR` generated columns on menu items (weighted A/B), trigram (`pg_trgm`) indexes for fuzzy matching, and `websearch_to_tsquery` for natural-language search via `api.search_menu(q)`.
- **Row-Level Security** — Customers see only their own orders and items. Staff see all. PostgREST JWT claims are used to identify the requesting user.
- **Audit logging (pgaudit + trigger)** — Two-layer audit system: pgaudit logs all DDL/role/write statements to `pg_log`; a row-level trigger captures before/after JSONB snapshots into `internal.audit_log` for every change to users, orders, order items, menu items, and stores.
- **BRIN indexes** — Audit log timestamps use BRIN indexes (`pages_per_range=128`) which are orders of magnitude smaller than B-tree for append-only, time-ordered tables.
- **Monthly partitioning** — `internal.audit_log` is range-partitioned by month. `internal.create_next_audit_partition()` rolls the window forward.
- **Opening hours** — Per-store, per-day open/close times with an `is_store_open()` function evaluated in `Australia/Sydney` timezone.
- **Auth event logging** — Signup and login attempts (success and failure) are recorded in `internal.auth_log`, partitioned by month. Staff can query the full auth history via `GET /auth_log`.
- **Observability stack** — Prometheus scrapes `postgres_exporter` (internal DB metrics) and `cAdvisor` (container resource usage). Grafana ships a pre-provisioned queue-depth dashboard with a direct PostgreSQL datasource, auto-refreshing every 5 seconds.

## Stack

| Component | Version | Role |
|---|---|---|
| PostgreSQL | 17 | Database |
| PostGIS | 3.x (PGDG apt) | Geospatial queries |
| pgvector | latest | Vectorized full-text search |
| pgaudit | latest | Audit logging |
| PostgREST | latest | Auto-generated REST API |
| Swagger UI | latest | Interactive API docs |
| postgres_exporter | latest | Exports PostgreSQL metrics in Prometheus format |
| cAdvisor | latest | Per-container CPU, memory, and network metrics |
| Prometheus | latest | Metrics scraping and storage |
| Grafana | latest | Queue monitor dashboard and observability UI |

## Schema

### `internal` (private — never exposed directly)

| Table | Key columns |
|---|---|
| `users` | `id`, `email`, `password_hash` (pgcrypto), `first_name`, `last_name`, `suburb_id`, `role` |
| `suburbs` | `id`, `name`, `postcode`, `location GEOGRAPHY(POINT)` |
| `stores` | `id`, `name`, `address`, `suburb_id`, `location GEOGRAPHY(POINT)`, `phone`, `is_active` |
| `store_hours` | `store_id`, `day_of_week` (ISODOW 1–7), `open_time`, `close_time`, `is_closed` |
| `menu_categories` | `starter`, `classic`, `vegetarian`, `special` |
| `pizza_sizes` | `personal`, `small`, `medium`, `large`, `xl` |
| `pizza_bases` | `classic`, `thin`, `thick`, `stuffed_crust`, `gluten_free` |
| `menu_items` | `id`, `category_id`, `name`, `description`, `base_price`, `search_vector TSVECTOR` |
| `menu_item_variants` | `menu_item_id`, `size_id`, `base_id`, `price` |
| `orders` | `id`, `user_id`, `store_id`, `status` (pending → processing → processed), `total_amount` |
| `order_items` | `order_id`, `item_id`, `variant_id`, `quantity`, `unit_price` |
| `audit_log` | `occurred_at`, `db_user`, `app_user_id`, `app_role`, `schema_name`, `table_name`, `operation`, `old_data JSONB`, `new_data JSONB`, `changed_cols[]`, `txid` |
| `auth_log` | `occurred_at`, `event_type` (signup/login_success/login_failure), `email`, `user_id`, `ip_addr`, `details JSONB` |

### `api` (PostgREST-exposed)

| Endpoint | Role | Description |
|---|---|---|
| `GET /menu` | anon+ | Full menu with category |
| `GET /menu_variants` | anon+ | Size/base/price combinations |
| `GET /stores` | anon+ | Stores with `is_open_now` flag |
| `GET /store_hours` | anon+ | Weekly trading hours per store |
| `GET /orders` | customer+ | Own orders (RLS enforced) |
| `GET /order_items` | customer+ | Items within own orders |
| `POST /rpc/search_menu` | anon+ | Full-text + trigram menu search |
| `POST /rpc/stores_near` | anon+ | Nearest stores to a suburb name |
| `POST /rpc/place_order` | customer | Create a new order |
| `POST /rpc/claim_next_order` | staff | Claim next pending order (SKIP LOCKED) |
| `POST /rpc/complete_order` | staff | Mark an order as processed |
| `GET /audit_log` | staff | Full audit trail |
| `POST /rpc/order_audit` | staff | Audit history for a single order |
| `GET /auth_log` | staff | Signup and login event history |

## How to run

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes Compose)

### 1. Start all services

```bash
docker compose up --build
```

**Apple Silicon (M1/M2/M3)** — build native `arm64` images by prefixing the command:

```bash
DOCKER_DEFAULT_PLATFORM=linux/arm64 docker compose up --build
```

This builds the PostgreSQL image, applies all SQL migrations in order, and
starts PostgREST and Swagger UI. On first run the database schema and seed data
are created automatically — subsequent starts reuse the `pgdata` volume.

| Service | URL |
|---|---|
| Pizza app (frontend) | http://localhost:8000 |
| PostgREST API | http://localhost:3000 |
| Swagger UI | http://localhost:8080 |
| Adminer (DB viewer) | http://localhost:8090 |
| Grafana (queue monitor) | http://localhost:3001 |
| Prometheus | http://localhost:9090 |
| PostgreSQL | localhost:5432 |

### 2. Demo credentials

Two accounts are created on first boot:

| Role | Email | Password |
|---|---|---|
| Customer | `demo@slices.com.au` | `password123` |
| Staff | `staff@slices.com.au` | `password123` |

The customer account has 4 pre-seeded orders (2 processed, 1 in processing, 1 pending) so order history is immediately visible without placing a new order.

Log in via `POST /rpc/login` to get a JWT, then use it as a Bearer token for authenticated endpoints.

### 3. Explore the API with Swagger UI

Open **http://localhost:8080** in your browser. Every endpoint is documented
with request/response schemas and a **Try it out** button.

Unauthenticated endpoints (menu, stores, search) work immediately with no token.
For `customer` and `staff` endpoints, generate a JWT first (see step 4) and
paste it into the **Authorize** dialog (padlock icon, top right).

### 4. Generate a JWT manually (optional)

The default secret is `super-secret-jwt-key-change-in-production`. Use any
JWT tool, for example the [jwt.io debugger](https://jwt.io) or the `jwt` CLI:

```bash
# Install once
npm install -g jsonwebtoken-cli

# Customer token (replace the sub with a real user UUID after creating a user)
jwt sign --secret 'super-secret-jwt-key-change-in-production' \
  '{"role":"customer","sub":"00000000-0000-0000-0000-000000000000"}'

# Staff token
jwt sign --secret 'super-secret-jwt-key-change-in-production' \
  '{"role":"staff","sub":"00000000-0000-0000-0000-000000000000"}'
```

Pass the token as a Bearer header:
```
Authorization: Bearer <token>
```

To use a custom secret, set `JWT_SECRET` before starting:
```bash
JWT_SECRET=my-production-secret docker compose up
```

### 5. Browse the database with Adminer

Open **http://localhost:8090** in your browser. Adminer is a lightweight open-source
web UI for PostgreSQL. Log in with:

| Field | Value |
|---|---|
| System | PostgreSQL |
| Server | `db` |
| Username | `postgres` |
| Password | `postgres` |
| Database | `pizza` |

From here you can browse tables, run SQL queries, inspect indexes, view partitions,
and explore the audit log — all without installing any local database tooling.

### 6. Run the high-throughput load test

The load test inserts a large batch of orders while a pool of SKIP LOCKED workers
drains the queue concurrently, demonstrating zero deadlocks or lost updates under load.

```bash
# Install dependencies (one-time)
cd scripts && npm install

# Run with defaults: 2 000 total orders, 500 per batch wave, 5 worker connections
node load-test.js

# Custom parameters
node load-test.js --total=5000 --batch=1000 --workers=8

# With a remote database
node load-test.js --host=mydb.example.com --port=5432
```

> The script connects directly to PostgreSQL on `localhost:5432`.
> The database must already be running (`docker compose up`).

| Option | Default | Description |
|---|---|---|
| `--total` | `2000` | Total orders to insert |
| `--batch` | `500` | Inserts per concurrent wave |
| `--workers` | `5` | Concurrent SKIP LOCKED claiming workers |
| `--host` | `localhost` | Database host |
| `--port` | `5432` | Database port |

**What it measures:**

| Metric | What it shows |
|---|---|
| Effective TPS | Actual sustained inserts per second under load |
| Queue cleared | Whether all orders moved from `pending` → `processed` |
| Insert errors | Any constraint or lock violations during inserts |
| Claim errors | Any concurrency errors during SKIP LOCKED claiming |
| Claim latency | p50/p95/p99/max ms from order creation to worker claim |

Because `FOR UPDATE SKIP LOCKED` lets each worker skip rows already held by another
worker (rather than blocking), the queue drains in parallel with zero contention.

### 7. Browse metrics and dashboards

**Grafana** (http://localhost:3001) ships with two pre-provisioned datasources and a
queue-depth dashboard:

- **PostgreSQL datasource** — queries `internal` tables directly (queue depth, order
  status breakdown, per-store throughput). Auto-refreshes every 5 seconds.
- **Prometheus datasource** — visualise `postgres_exporter` connection counts, cache
  hit ratio, and `cAdvisor` container CPU/memory.

Default credentials: `admin` / `admin`. Anonymous access is enabled so no login is
required.

**Prometheus** (http://localhost:9090) stores 7 days of metrics and scrapes:
- `postgres_exporter` — PostgreSQL internals (connections, locks, bgwriter, etc.)
- `cAdvisor` — per-container CPU, memory, and network I/O

### 8. Connect directly to PostgreSQL (optional)

```bash
docker compose exec db psql -U postgres -d pizza
```

### 9. Tear down

```bash
# Stop containers, keep data volume
docker compose down

# Stop and delete all data (full reset)
docker compose down -v
```

## File layout

```
.
├── Dockerfile
├── docker-compose.yml
├── openapi.yaml           # OpenAPI 3.1 spec (loaded by Swagger UI)
├── public/
│   ├── index.html         # Sign in / sign up
│   └── app.html           # Store selector (map), menu, order history
├── scripts/
│   ├── package.json
│   └── load-test.js       # High-throughput load test (2 000 orders, SKIP LOCKED drain)
├── grafana/
│   └── provisioning/
│       ├── dashboards/    # Pre-built queue-depth dashboard (queue.json)
│       └── datasources/   # PostgreSQL + Prometheus datasource configs
├── prometheus/
│   └── prometheus.yml     # Scrape config for postgres_exporter and cAdvisor
└── sql/
    ├── 01-schema.sql      # Extensions, roles, tables, partitions, indexes, triggers,
    │                      # RLS, API views/functions, grants, auth logging
    ├── 02-seed.sql        # Sydney suburbs, stores, menu, demo users & orders
    └── 03-audit.sql       # Audit extension: pgaudit setup, audit_log + auth_log
                           # tables, BRIN indexes, trigger function, API views
```
