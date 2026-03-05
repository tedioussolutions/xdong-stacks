-- =============================================================================
-- local-dev stack: Multi-Database Initialization Script
-- =============================================================================
-- This script runs automatically once when the postgres container first starts
-- (any .sql files in /docker-entrypoint-initdb.d/ are executed in sort order).
-- Re-running only happens if the postgres data volume is wiped.
--
-- To re-initialize: docker compose down -v && docker compose up -d
-- =============================================================================

-- ── Forgejo: Self-hosted Git service ─────────────────────────────────────────
CREATE DATABASE forgejo;
CREATE USER forgejo WITH ENCRYPTED PASSWORD 'change-me-forgejo';
GRANT ALL PRIVILEGES ON DATABASE forgejo TO forgejo;
-- Required for Forgejo to create schemas in its database (PostgreSQL 15+ default)
\connect forgejo
GRANT ALL ON SCHEMA public TO forgejo;

-- ── n8n: Workflow automation ──────────────────────────────────────────────────
\connect postgres
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'change-me-n8n';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
\connect n8n
GRANT ALL ON SCHEMA public TO n8n;

-- ── Bytebase: Database DevOps tool ───────────────────────────────────────────
\connect postgres
CREATE DATABASE bytebase;
CREATE USER bytebase WITH ENCRYPTED PASSWORD 'change-me-bytebase';
GRANT ALL PRIVILEGES ON DATABASE bytebase TO bytebase;
\connect bytebase
GRANT ALL ON SCHEMA public TO bytebase;

-- ── Activepieces: Workflow automation platform ───────────────────────────────
\connect postgres
CREATE DATABASE activepieces;
CREATE USER activepieces WITH ENCRYPTED PASSWORD 'change-me-activepieces';
GRANT ALL PRIVILEGES ON DATABASE activepieces TO activepieces;
\connect activepieces
GRANT ALL ON SCHEMA public TO activepieces;
