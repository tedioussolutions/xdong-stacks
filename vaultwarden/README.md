# Vaultwarden Stack

Self-hosted Bitwarden-compatible password manager. Works with the official Bitwarden browser extensions and mobile apps.

| Service | Image | Purpose |
|---------|-------|---------|
| Vaultwarden | `vaultwarden/server:latest` | Password vault + admin panel |

---

## Prerequisites

- Docker + Docker Compose v2
- **A reverse proxy terminating HTTPS** — Bitwarden clients require HTTPS. Caddy, Traefik, or nginx all work.
- A domain name with a valid TLS certificate pointing to this host

> **Why HTTPS is non-negotiable:** Browser extensions and mobile apps refuse to connect over plain HTTP. All passwords transit this connection — encryption in transit is mandatory.

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/vaultwarden
```

**2. Copy and configure environment:**
```bash
cp .env.example .env
nano .env  # Set DOMAIN and ADMIN_TOKEN at minimum
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

**5. Create your account:** Open `https://YOUR_DOMAIN` in a browser and register. Do this **before** setting `SIGNUPS_ALLOWED=false`.

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Full HTTPS URL (e.g. `https://vault.example.com`) |
| `ADMIN_TOKEN` | Yes | — | Token for `/admin` panel — generate with `openssl rand -base64 48` |
| `SIGNUPS_ALLOWED` | No | `false` | Allow public registration — enable only during initial setup |
| `VAULTWARDEN_PORT` | No | `8080` | Host port your reverse proxy forwards to |
| `PUID` / `PGID` | No | `1000` | User/group ID for volume file ownership |

---

## Post-Deploy Checklist

1. **Create your account** at `https://YOUR_DOMAIN` (signup must be enabled)
2. **Disable signups:** Set `SIGNUPS_ALLOWED=false` in `.env`, then `docker compose up -d`
3. **Access admin panel** at `https://YOUR_DOMAIN/admin` using your `ADMIN_TOKEN`
4. **Install Bitwarden client** — browser extension or mobile app, point it at your domain
5. **Configure backups** for the `vaultwarden-data` Docker volume (contains your encrypted vault)

---

## Security Notes

- Rotate `ADMIN_TOKEN` regularly — the admin panel has no rate limiting by default
- Back up `vaultwarden-data` volume — losing it means losing all vault data
- Keep `SIGNUPS_ALLOWED=false` in production; invite users via the admin panel
- Vaultwarden encrypts vault data client-side — the server never sees plaintext passwords

---

## Related

- [xdong.sh Password Manager Guide](https://xdong.sh/guides/password-manager) — full walkthrough
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Bitwarden clients](https://bitwarden.com/download/) — official browser extensions and mobile apps
