# Nextcloud AIO Stack

Self-hosted file sync, sharing, and collaboration platform. The All-in-One image runs a single mastercontainer that spawns and manages all sub-containers (Nextcloud app, PostgreSQL, Redis, Collabora Online, Talk, etc.) automatically.

| Service | Image | Purpose |
|---------|-------|---------|
| AIO Mastercontainer | `nextcloud/all-in-one:latest` | Dashboard + sub-container lifecycle manager |
| Sub-containers | Managed by AIO | App, DB, cache, office, talk, backup |

---

## Prerequisites

- Docker + Docker Compose v2
- Docker socket accessible at `/var/run/docker.sock` (AIO spawns sub-containers via it)
- A reverse proxy (Caddy, Traefik, nginx) if you want HTTPS — strongly recommended
- Ports `8080` (AIO dashboard) and `11000` (Nextcloud Apache) open in your firewall

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/nextcloud
```

**2. Copy and configure environment:**
```bash
cp .env.example .env
nano .env  # Set NEXTCLOUD_TRUSTED_DOMAINS at minimum
```

**3. Validate configuration:**
```bash
bash validate.sh
```

**4. Deploy:**
```bash
docker compose up -d
docker compose logs -f nextcloud-aio
```

**5. Open the AIO dashboard** at `http://localhost:8080` and save the passphrase it shows you — you need it to log back in.

**6. Follow the setup wizard** — AIO pulls sub-container images and starts Nextcloud. This takes 5–10 minutes on first run.

**7. Access Nextcloud** at `http://localhost:11000` (or your reverse proxy domain) once the wizard completes.

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXTCLOUD_DATADIR` | Docker volume | Host path or volume name for user data |
| `APACHE_PORT` | `11000` | Port the Nextcloud Apache frontend binds on |
| `NEXTCLOUD_AIO_PORT` | `8080` | Port the AIO mastercontainer dashboard binds on |
| `NEXTCLOUD_TRUSTED_DOMAINS` | `nextcloud.local` | Comma-separated trusted hostnames/IPs |
| `TZ` | `America/Denver` | Timezone for all sub-containers |
| `PUID` / `PGID` | `1000` | User/group ID for file ownership |

---

## Volumes

| Volume | Purpose |
|--------|---------|
| `nextcloud-aio-mastercontainer` | AIO mastercontainer config, passphrase, state |
| `nextcloud_aio_nextcloud_datadir` | Nextcloud user files (if using default volume) |

Sub-containers also create their own volumes (PostgreSQL data, Redis data, etc.) — AIO names and manages these automatically.

---

## Reverse Proxy (HTTPS)

Point your reverse proxy at `http://localhost:11000` (or `APACHE_PORT`). Example Caddy snippet:

```
nextcloud.example.com {
    reverse_proxy localhost:11000
}
```

Add `nextcloud.example.com` to `NEXTCLOUD_TRUSTED_DOMAINS` in `.env`, then restart:
```bash
docker compose up -d
```

---

## Backup

AIO includes a built-in backup solution (Borg) configurable from the dashboard at `http://localhost:8080`. Recommended approach:

1. Open AIO dashboard → Backup & restore
2. Set a backup target (local path or remote via Borg)
3. Schedule daily automated backups

Manual volume backup (offline):
```bash
docker compose down
tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz \
  $(docker volume inspect nextcloud-aio-mastercontainer -f '{{.Mountpoint}}')
docker compose up -d
```

---

## Troubleshooting

**AIO dashboard not loading at :8080**
- Check container is running: `docker compose ps`
- Check logs: `docker compose logs nextcloud-aio`
- Verify port is not already in use: `ss -tlnp | grep 8080`

**Sub-containers fail to start**
- Ensure `/var/run/docker.sock` is accessible: `ls -la /var/run/docker.sock`
- Check Docker socket permissions — your user must be in the `docker` group
- Review AIO dashboard logs for sub-container pull/start errors

**Nextcloud not reachable at :11000**
- Sub-containers are started by AIO after dashboard setup — complete the wizard first
- Check `APACHE_PORT` matches the port you're connecting to
- Confirm `NEXTCLOUD_TRUSTED_DOMAINS` includes the hostname you're accessing

**"Access through untrusted domain" error**
- Add the domain/IP to `NEXTCLOUD_TRUSTED_DOMAINS` in `.env`
- Restart: `docker compose up -d`

---

## Related

- [Nextcloud AIO documentation](https://github.com/nextcloud/all-in-one)
- [Reverse proxy configuration examples](https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md)
- [xdong.sh Nextcloud guide](https://xdong.sh/guides/nextcloud)
