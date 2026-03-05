# Caddy Reverse Proxy Stack

Standalone Caddy reverse proxy — the foundation for all other xdong.sh stacks.

Deploy this first. Every other stack attaches to the `proxy` network this stack creates, so Caddy can route traffic to them without exposing individual ports.

**Guide:** https://xdong.sh/guides/reverse-proxy

---

## Quick Start

```bash
cp .env.example .env
# Edit .env if ports 80/443 are taken
docker compose up -d
```

Caddy starts in HTTP-only mode with no routes configured. Add your site blocks to `Caddyfile`, then reload.

---

## Editing the Caddyfile

Add a block per site. Caddy watches for config changes — reload without downtime:

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**Reverse proxy to a container on the proxy network:**

```
app.yourdomain.com {
    reverse_proxy app-container-name:8080
}
```

**Reverse proxy to a port on the host:**

```
app.yourdomain.com {
    reverse_proxy host.docker.internal:8080
}
```

---

## HTTPS with Let's Encrypt

1. Point your domain's DNS A record to this machine's public IP.
2. Open `.env` and confirm `HTTP_PORT=80` and `HTTPS_PORT=443` (Let's Encrypt requires these).
3. Edit `Caddyfile` — uncomment the email line in the global block:

```
{
    email your@email.com
}
```

4. Add your site block (plain — no `tls` directive needed):

```
app.yourdomain.com {
    reverse_proxy app-container-name:8080
}
```

5. Reload: `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`

Caddy obtains and renews certificates automatically. Cert data persists in the `caddy-data` volume.

---

## DNS Requirements

| Scenario | DNS setup |
|----------|-----------|
| Public HTTPS | A record pointing domain to your public IP |
| LAN-only `.local` | Wildcard record in Pi-hole / AdGuard Home, or `/etc/hosts` entries |
| LAN-only real domain | Split-horizon DNS or local override in your resolver |

---

## Shared Proxy Network

This stack creates a Docker bridge network named `proxy`. Other stacks join it with:

```yaml
networks:
  proxy:
    external: true
```

Containers on the `proxy` network are reachable by their `container_name` from Caddy — no host-port exposure needed.

---

## Validation

```bash
bash validate.sh
```

Checks: `.env` present, `Caddyfile` present, Compose syntax valid, ports 80/443 not already bound.
