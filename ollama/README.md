# Ollama + Open WebUI Stack

Docker Compose stack for running local LLMs — Ollama handles inference, Open WebUI provides a browser-based chat interface similar to ChatGPT.

---

## Prerequisites

- Docker + Docker Compose v2
- Linux host (x86_64 or arm64)
- 8 GB+ RAM recommended; 16 GB+ for 13B+ models
- (Optional) NVIDIA GPU + NVIDIA Container Toolkit for GPU acceleration

---

## Quick Start

**1. Enter the stack directory:**
```bash
cd xdong-stacks/ollama
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

**5. Pull your first model and open the UI:**
```bash
docker exec ollama ollama pull llama3.2
```
Then open: `http://localhost:3000`

---

## GPU Setup (NVIDIA)

**1. Install NVIDIA Container Toolkit on the host:**
```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

**2. Enable GPU in `docker-compose.yml`:**

Uncomment the `deploy` block under the `ollama` service:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

**3. Restart the stack:**
```bash
docker compose up -d
```

**4. Verify GPU is detected:**
```bash
docker exec ollama ollama run llama3.2 "What GPU are you using?"
```

---

## Model Management

**Pull a model:**
```bash
docker exec ollama ollama pull llama3.2          # 2B — fast, low RAM
docker exec ollama ollama pull llama3.1:8b       # 8B — good balance
docker exec ollama ollama pull mistral           # 7B — strong reasoning
docker exec ollama ollama pull codellama:13b     # 13B — code focused
```

**List downloaded models:**
```bash
docker exec ollama ollama list
```

**Remove a model:**
```bash
docker exec ollama ollama rm llama3.2
```

Browse all available models at [ollama.com/library](https://ollama.com/library).

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_PORT` | `11434` | Host port for the Ollama API |
| `WEBUI_PORT` | `3000` | Host port for the Open WebUI interface |
| `TZ` | `America/Denver` | Timezone for container log timestamps |
| `OLLAMA_MODELS` | _(named volume)_ | Optional host path for model storage |

---

## Troubleshooting

**Open WebUI shows "Connection error" on first load**
→ Ollama may still be starting. Wait 30 seconds and refresh. Check with `docker compose ps`.

**Out of memory when running a model**
→ Use a smaller model variant (e.g. `llama3.2:1b` instead of `llama3.2`). Check available RAM with `free -h`.

**Port already in use**
→ Change `OLLAMA_PORT` or `WEBUI_PORT` in `.env`, then `docker compose up -d`.

**GPU not detected inside container**
→ Verify `nvidia-smi` works on the host. Confirm the `deploy` block is uncommented in `docker-compose.yml`. Restart Docker after installing the NVIDIA Container Toolkit.

---

## Related

- [Ollama model library](https://ollama.com/library)
- [Open WebUI docs](https://docs.openwebui.com/)
- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
