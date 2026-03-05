# Home Assistant Stack

Docker Compose stack for Home Assistant — a privacy-focused, local smart home platform.

| Service | Image | Purpose |
|---------|-------|---------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:stable` | Smart home hub and automation engine |
| Mosquitto | `eclipse-mosquitto:2` | MQTT broker for Zigbee/Z-Wave device integration (optional) |

---

## Prerequisites

- Docker + Docker Compose v2
- Linux host (recommended) or macOS
- Port 8123 available (or set `HA_PORT` in `.env`)

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/home-assistant
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

**5. Access Home Assistant:** http://localhost:8123

---

## MQTT Profile (Zigbee / Z-Wave)

Mosquitto is opt-in. Enable it alongside Home Assistant:

```bash
docker compose --profile mqtt up -d
```

Then add the MQTT integration in Home Assistant:
**Settings → Devices & Services → Add Integration → MQTT**
- Broker: `homeassistant-mosquitto` (or your host IP)
- Port: `1883`

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Denver` | Timezone for Home Assistant |
| `HA_PORT` | `8123` | Host port for the web UI |
| `MQTT_PORT` | `1883` | Host port for Mosquitto MQTT broker |

---

## Post-Deploy

**Onboarding wizard** runs on first visit to http://localhost:8123 — create your admin account and set your home location.

**Add integrations:** Settings → Devices & Services → Add Integration. Popular integrations: Google Cast, Philips Hue, MQTT, ESPHome, Zigbee2MQTT.

**Automations:** Settings → Automations & Scenes → Create Automation.

---

## USB Device Passthrough (Zigbee / Z-Wave dongles)

If you use a USB Zigbee or Z-Wave coordinator (e.g. ConBee II, Sonoff Zigbee 3.0, Zooz), add a device mapping to the `homeassistant` service in `docker-compose.yml`:

```yaml
services:
  homeassistant:
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0   # adjust path as needed
```

Find your dongle's path: `ls /dev/tty{USB,ACM}*` after plugging it in.

---

## Related

- [xdong.sh Home Assistant guide](https://xdong.sh/guides/home-assistant-core) — full walkthrough
- [Home Assistant docs](https://www.home-assistant.io/docs/)
- [Mosquitto docs](https://mosquitto.org/documentation/)
- [Zigbee2MQTT](https://www.zigbee2mqtt.io/) — pairs with the MQTT profile above
