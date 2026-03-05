# local-dev Stack

A fully-featured self-hosted local development environment with 14 services spanning AI/ML tooling, automation, databases, and developer utilities. All services are accessible via direct `localhost` port access — no DNS setup, no reverse proxy required.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | http://localhost:3000 | Central dashboard with status tiles |
| Code-Server | http://localhost:8443 | VS Code in the browser |
| Forgejo | http://localhost:3001 | Self-hosted Git service |
| Forgejo SSH | ssh://localhost:2222 | Git over SSH |
| Qdrant | http://localhost:6333 | Vector database (REST + Web UI) |
| Meilisearch | http://localhost:7700 | Full-text search engine |
| n8n | http://localhost:5678 | Workflow automation |
| Dozzle | http://localhost:8080 | Real-time Docker log viewer |
| Bytebase | http://localhost:8888 | Database schema migrations & DevOps |
| Open WebUI | http://localhost:8081 | AI chat interface (Ollama frontend) |
| Activepieces | http://localhost:8082 | Open-source automation platform |
| CyberChef | http://localhost:8083 | Data encoding/decoding toolkit |
| AnythingLLM | http://localhost:3500 | Self-hosted LLM workspace |

**Infrastructure (no host ports):**

| Service | Purpose |
|---------|---------|
| Postgres 16 | Shared DB for Forgejo, n8n, Bytebase, Activepieces |
| Redis 7 | Cache/sessions for Forgejo + Activepieces |

## Quick Start

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Generate required secrets (replace placeholders in .env)
#    32-char hex key:   openssl rand -hex 16
#    64-char hex key:   openssl rand -hex 32
#    Base64 secret:     openssl rand -base64 32
nano .env

# 3. Validate the configuration
bash validate-stack-config.sh

# 4. Start the stack
docker compose up -d

# 5. Open the dashboard
open http://localhost:3000
```

## Architecture

```
┌─────────────────────────── local-dev-net ──────────────────────────────┐
│                                                                         │
│  postgres:5432 ──────── forgejo, n8n, bytebase, activepieces           │
│  redis:6379 ─────────── forgejo (cache), activepieces                  │
│  /var/run/docker.sock ─ homepage (ro), dozzle (ro)                     │
│  host.docker.internal ─ open-webui, anythingllm → Ollama on host       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Shared Postgres

A single Postgres 16 instance hosts multiple logical databases. On first start, `postgres/init/01-create-databases.sql` creates:

| Database | User | Used by |
|----------|------|---------|
| `forgejo` | `forgejo` | Forgejo Git service |
| `n8n` | `n8n` | n8n workflow automation |
| `bytebase` | `bytebase` | Bytebase metadata store |
| `activepieces` | `activepieces` | Activepieces automation |

> **Note:** The init script runs only once on first volume initialization. To re-initialize, run `docker compose down -v` to wipe volumes, then `docker compose up -d`.

## Configuration

All configuration is via `.env`. Copy `.env.example` to `.env` and edit:

### Required Secrets (no defaults — must set)

| Variable | Purpose | Generate with |
|----------|---------|--------------|
| `POSTGRES_PASSWORD` | Postgres superuser password | any strong password |
| `FORGEJO_DB_PASSWORD` | Forgejo DB user password | any strong password |
| `N8N_DB_PASSWORD` | n8n DB user password | any strong password |
| `BYTEBASE_DB_PASSWORD` | Bytebase DB user password | any strong password |
| `ACTIVEPIECES_DB_PASSWORD` | Activepieces DB user password | any strong password |
| `CODE_SERVER_PASSWORD` | Code-Server UI password | any strong password |
| `MEILI_MASTER_KEY` | Meilisearch master key | `openssl rand -hex 16` |
| `OPEN_WEBUI_SECRET_KEY` | Open WebUI session secret | `openssl rand -hex 32` |
| `AP_ENCRYPTION_KEY` | Activepieces encryption key (32 hex) | `openssl rand -hex 16` |
| `AP_JWT_SECRET` | Activepieces JWT secret (32 hex) | `openssl rand -hex 16` |
| `ANYTHINGLLM_JWT_SECRET` | AnythingLLM JWT signing key | `openssl rand -base64 32` |
| `ANYTHINGLLM_PASSWORD` | AnythingLLM UI password | any strong password |

> ⚠️ **Important:** The passwords in `.env` for Forgejo, n8n, Bytebase, and Activepieces must match the values used in `postgres/init/01-create-databases.sql`. If you change `.env` passwords after the volume is initialized, you must also run `docker compose exec postgres psql -U postgres -c "ALTER USER <user> WITH PASSWORD '<newpass>';"`.

### Optional Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Denver` | Timezone for all services |
| `PUID` / `PGID` | `1000` | User/group IDs for file ownership |
| `QDRANT_API_KEY` | (empty) | Leave empty to disable Qdrant auth |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama URL for Open WebUI |
| `N8N_HOST` | `localhost` | n8n public hostname |
| `N8N_WEBHOOK_URL` | `http://localhost:5678` | n8n webhook base URL |

## Ollama Integration

Open WebUI and AnythingLLM both support Ollama for local LLM inference. Both use `host.docker.internal` (mapped to the Docker host via `host-gateway`) to reach an Ollama instance running on the host machine.

**If `host.docker.internal` doesn't resolve on your system** (e.g., some older Linux setups), set the env var to your host's actual IP:
```bash
OLLAMA_BASE_URL=http://192.168.1.100:11434
```

## Forgejo First-Run Setup

On first access to http://localhost:3001, Forgejo shows an installation page. Most fields are pre-filled from environment variables. Verify:
- **Database** settings come from `FORGEJO__database__*` env vars — no changes needed
- Set an **admin username and password** on the setup form
- **Site URL** should be `http://localhost:3001`

## Bytebase First-Run Setup

On first access to http://localhost:8888, Bytebase asks for an admin email and password. After registering, add your databases via the web UI (e.g., connect to `postgres:5432` using the `bytebase` superuser credentials to manage schemas for other services in the stack).

## Volumes

All persistent data uses named Docker volumes:

```
postgres-data        redis-data          code-server-data
forgejo-data         qdrant-data         meilisearch-data
n8n-data             bytebase-data       open-webui-data
activepieces-data    anythingllm-data
```

List volumes: `docker volume ls | grep local-dev`

Wipe all data and start fresh:
```bash
docker compose down -v
docker compose up -d
```

## Troubleshooting

### Services depending on Postgres fail to start

Postgres has a health check (`pg_isready`) with a 30-second start period. Dependent services (`forgejo`, `n8n`, `bytebase`, `activepieces`) use `condition: service_healthy` so they wait automatically. If they still fail:

```bash
# Check Postgres health
docker compose ps postgres
docker compose logs postgres --tail 50
```

### Forgejo shows "database not found"

The init SQL script runs only on first volume creation. If Postgres was started before the init dir was in place:
```bash
docker compose down
docker volume rm $(docker volume ls -q | grep local-dev_postgres-data)
docker compose up -d
```

### Open WebUI can't connect to Ollama

1. Verify Ollama is running on the host: `curl http://localhost:11434/api/tags`
2. If `host.docker.internal` doesn't resolve, set `OLLAMA_BASE_URL` to your host IP in `.env`
3. Restart Open WebUI: `docker compose restart open-webui`

### Activepieces shows encryption error

`AP_ENCRYPTION_KEY` must be exactly 32 hex characters (not 32 bytes — 16 bytes = 32 hex chars). Verify:
```bash
echo -n "$AP_ENCRYPTION_KEY" | wc -c   # must output 32
```

### Port already in use

Check which process owns the port: `ss -tlnp | grep :<port>`

To change a port, update both sides of the mapping in `docker-compose.yml`:
```yaml
ports:
  - "9443:8443"   # change left side (host port) only
```
