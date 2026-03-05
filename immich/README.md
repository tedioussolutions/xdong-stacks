# Immich Stack

Self-hosted photo and video backup — a Google Photos alternative with mobile apps, smart search, face recognition, and shared albums.

| Service | Image | Purpose |
|---------|-------|---------|
| immich-server | `ghcr.io/immich-app/immich-server:release` | Web UI, API, background jobs |
| immich-machine-learning | `ghcr.io/immich-app/immich-machine-learning:release` | Smart search (CLIP) + face recognition |
| immich-postgres | `tensorchord/pgvecto-rs:pg16-v0.2.0` | Database with vector extension |
| immich-redis | `redis:6.2-alpine` | Job queue and caching |

---

## Prerequisites

- Docker + Docker Compose v2
- Linux host (x86_64 or arm64)
- Sufficient disk space for your photo/video library (plan for 2-3x raw library size)

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/immich
```

**2. Copy and configure environment:**
```bash
cp .env.example .env
nano .env  # Set DB_PASSWORD and UPLOAD_LOCATION at minimum
```

**3. Validate configuration:**
```bash
bash validate.sh
```

**4. Deploy:**
```bash
docker compose up -d
docker compose ps
```

**5. Open the web UI and create your admin account:**
```
http://localhost:2283
```

---

## Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_PASSWORD` | Yes | — | Postgres password — generate with `openssl rand -base64 32` |
| `UPLOAD_LOCATION` | No | `./library` | Host path for uploaded photos/videos |
| `IMMICH_PORT` | No | `2283` | Host port for the web UI |
| `DB_USERNAME` | No | `postgres` | Postgres username |
| `DB_DATABASE_NAME` | No | `immich` | Postgres database name |
| `TZ` | No | `America/Denver` | Timezone for timestamps and scheduled tasks |

---

## GPU Acceleration (Optional)

Immich machine learning can use a GPU for faster face recognition and CLIP encoding.

**NVIDIA (CUDA):**
```yaml
immich-machine-learning:
  image: ghcr.io/immich-app/immich-machine-learning:release-cuda
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]
```
Requires `nvidia-container-toolkit` installed on the host.

**Intel/AMD (OpenVINO / ROCm):**
Use the `-openvino` or `-rocm` image variants. See [Immich hardware acceleration docs](https://immich.app/docs/features/ml-hardware-acceleration).

---

## Backup

Immich data lives in two places — back up both:

1. **Database** — dump the Postgres volume:
   ```bash
   docker exec immich-postgres pg_dumpall -U postgres > immich-backup-$(date +%Y%m%d).sql
   ```

2. **Upload library** — back up the `UPLOAD_LOCATION` directory (or `immich-postgres-data` volume if using default).

Immich also has a built-in backup job: **Administration → Jobs → Database Backup**.

> Do not rely solely on volume snapshots — use `pg_dumpall` for the database to ensure a consistent, portable backup.

---

## Troubleshooting

**Smart search returns no results after upload**
Machine learning indexing runs in the background. Check job status at **Administration → Jobs → Smart Search**. First run can take minutes to hours depending on library size.

**Face recognition is not grouping people**
Facial recognition jobs must complete first. Go to **Administration → Jobs → Face Detection**, then **Administration → Jobs → Facial Recognition**.

**Port 2283 already in use**
Change `IMMICH_PORT` in `.env`, then `docker compose up -d`.

**Database fails to start**
`pgvecto-rs` requires `--data-checksums` on database initialization. If you previously initialized without it, drop the `immich-postgres-data` volume and restart: `docker compose down -v && docker compose up -d`. This deletes all data.

**Mobile app cannot connect**
Set the server URL in the app to `http://YOUR_HOST_IP:2283`. Ensure the port is reachable from your phone (same network, or exposed via reverse proxy for remote access).

---

## Related

- [xdong.sh guide — Photo Backup](https://xdong.sh/guides/photo-backup) — full walkthrough
- [Immich docs](https://immich.app/docs)
- [Immich GitHub](https://github.com/immich-app/immich)
