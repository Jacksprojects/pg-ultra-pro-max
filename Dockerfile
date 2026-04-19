FROM postgres:17

# Install PostGIS, pgvector, and pgaudit from the PGDG apt repo.
# postgres:17 is multi-arch (amd64 + arm64) and already has the PGDG repo
# configured, so all three packages resolve without any extra repo setup.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-17-postgis-3 \
        postgresql-17-postgis-3-scripts \
        postgresql-17-pgvector \
        postgresql-17-pgaudit \
    && rm -rf /var/lib/apt/lists/*

COPY sql/01-schema.sql /docker-entrypoint-initdb.d/01-schema.sql
COPY sql/02-seed.sql   /docker-entrypoint-initdb.d/02-seed.sql
