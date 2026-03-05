# Jellyfin Media Server Stack

Docker Compose stack for Jellyfin — open-source media server for movies, TV, music, and photos.

---

## Prerequisites

- Docker + Docker Compose v2
- Linux host (x86_64 or arm64)
- Media files accessible on the host filesystem

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/jellyfin
```

**2. Copy and configure environment:**
```bash
cp .env.example .env
nano .env
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

**5. Open the web UI:**
```
http://localhost:8096
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID that Jellyfin runs as (run `id` to find yours) |
| `PGID` | `1000` | Group ID that Jellyfin runs as |
| `MEDIA_PATH` | `/srv/media` | Absolute host path to your media directory (mounted read-only) |
| `JELLYFIN_PORT` | `8096` | Host port for the Jellyfin web UI |
| `JELLYFIN_URL` | `http://localhost:8096` | Public URL Jellyfin advertises to clients |

---

## Post-Deploy Steps

### 1. Initial Setup Wizard

On first launch, Jellyfin runs a setup wizard at `http://localhost:8096`:

1. Create your admin account
2. Add a media library — point it to `/media` (the container path)
3. Choose your preferred metadata language and image providers
4. Complete the wizard — Jellyfin will begin scanning your library

### 2. Library Scan

After adding libraries, trigger a manual scan if content does not appear automatically:

```
Dashboard → Libraries → (select library) → Scan Library
```

Or via the admin panel: **Dashboard → Scheduled Tasks → Scan Media Library → Run Now**

### 3. Remote Access (optional)

To access Jellyfin from other devices on your network:

1. Set `JELLYFIN_URL=http://YOUR_LAN_IP:8096` in `.env`
2. Restart the stack: `docker compose up -d`
3. Open `http://YOUR_LAN_IP:8096` from any device on the network

---

## Troubleshooting

**Jellyfin cannot read media files**
→ Check `PUID`/`PGID` match the owner of `MEDIA_PATH`. Run `ls -ln $MEDIA_PATH` to verify.

**Port 8096 already in use**
→ Change `JELLYFIN_PORT` in `.env`, then `docker compose up -d`.

**Metadata / artwork not loading**
→ Jellyfin fetches metadata from the internet. Verify outbound HTTPS is not blocked.

---

## Related

- [xdong.sh guide — Media Server](https://xdong.sh/guides/media-server) — full walkthrough
- [Jellyfin docs](https://jellyfin.org/docs/)
- [Jellyfin Docker Hub](https://hub.docker.com/r/jellyfin/jellyfin)
