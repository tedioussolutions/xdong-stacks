# AdGuard Home Stack

Network-wide ad blocking and privacy-focused DNS server. Blocks ads, trackers, and malicious domains for every device on your network — no per-device configuration needed.

| Service | Image | Purpose |
|---------|-------|---------|
| AdGuard Home | `adguard/adguardhome:latest` | DNS server + ad/tracker blocking |

---

## Prerequisites

- Docker + Docker Compose v2
- A Linux host (bare metal, VM, or Proxmox LXC)
- **Port 53 must be free** — Ubuntu 18.04+ and Debian 12+ use systemd-resolved on port 53 by default. See [Port 53 Conflict](#port-53-conflict) below before deploying.
- Router access to change the DNS server for your network (optional but recommended)

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/adguard
```

**2. Copy and configure environment:**
```bash
cp .env.example .env
nano .env  # Adjust ports if needed; defaults work for most setups
```

**3. Resolve port 53 conflict (Ubuntu/Debian only):**
```bash
# Check if port 53 is already in use
ss -tlnp | grep :53
# If systemd-resolved is listed, see "Port 53 Conflict" section below
```

**4. Validate configuration:**
```bash
bash validate.sh
```

**5. Deploy:**
```bash
docker compose up -d
docker compose ps
```

**6. Complete the setup wizard:**
Open `http://YOUR_HOST_IP:3000` in a browser. The wizard runs once and configures your admin credentials and initial DNS settings.

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ADGUARD_WEB_PORT` | `3000` | Web UI and initial setup wizard |
| `ADGUARD_DNS_PORT` | `53` | Plain DNS (TCP + UDP) — point clients here |
| `ADGUARD_HTTPS_PORT` | `443` | DNS-over-HTTPS (DoH) |
| `ADGUARD_DNS_QUIC_PORT` | `853` | DNS-over-TLS (DoT) |
| `TZ` | `America/Denver` | Timezone for query log timestamps |

After the setup wizard completes, the web UI is accessible at `http://YOUR_HOST_IP:3000` (management dashboard stays on port 3000).

---

## DNS Setup

### Option A — Router (recommended)

Set your router's DNS server to your AdGuard host's IP. All devices on the network use AdGuard automatically.

1. Log in to your router admin panel
2. Find DHCP or DNS settings
3. Set primary DNS to your AdGuard host IP (e.g. `192.168.1.10`)
4. Set secondary DNS to a fallback (e.g. `1.1.1.1`) for redundancy
5. Save and reboot the router

### Option B — Per device

Set the DNS server manually on each device to your AdGuard host IP.

### Encrypted DNS (optional)

For DNS-over-HTTPS, point clients to:
```
https://YOUR_HOST_IP/dns-query
```

For DNS-over-TLS, point clients to:
```
YOUR_HOST_IP:853
```

Encrypted DNS requires a TLS certificate. Configure it in AdGuard Home → Settings → Encryption.

---

## Port 53 Conflict

Ubuntu 18.04+ and Debian 12+ run `systemd-resolved` which binds port 53 on `127.0.0.53`. This prevents AdGuard from binding to port 53.

**Fix — disable the systemd-resolved stub listener:**

```bash
# Edit the resolved config
sudo nano /etc/systemd/resolved.conf
```

Add or update this line under `[Resolve]`:
```ini
DNSStubListener=no
```

Then restart and update the symlink:
```bash
sudo systemctl restart systemd-resolved
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

Verify port 53 is now free:
```bash
ss -tlnp | grep :53
# Should show nothing (or only your AdGuard container after it starts)
```

> **Note:** This only affects the stub listener on `127.0.0.53`. systemd-resolved continues handling DNS for the host itself via the upstream resolvers configured in `/etc/systemd/resolved.conf`.

---

## Troubleshooting

**Container exits immediately / port 53 bind error**
Port 53 is in use. Run `ss -tlnp | grep :53` to identify the process. Follow the Port 53 Conflict steps above if it's systemd-resolved.

**Web UI not reachable after setup wizard**
The wizard redirects to port 80 inside the container, but this stack exposes management via port 3000. Access the dashboard at `http://YOUR_HOST_IP:3000` directly.

**DNS queries not being blocked**
Confirm clients are actually using AdGuard: run `nslookup doubleclick.net YOUR_HOST_IP` — the response should return `0.0.0.0`. If it returns a real IP, the client is using a different DNS server.

**Query log shows no traffic**
Your router or devices are not pointing to AdGuard yet. See [DNS Setup](#dns-setup) above.

---

## Related

- [AdGuard Home GitHub](https://github.com/AdguardTeam/AdGuardHome)
- [AdGuard Home Wiki](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Popular blocklists](https://github.com/nicehash/NiceHashQuickMiner/wiki/DNS-Block-List) — add under Filters → DNS Blocklists in the UI
