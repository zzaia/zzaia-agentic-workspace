# Custom DinD (Docker-in-Docker) with NVIDIA Container Toolkit

This custom Docker-in-Docker image extends the official `docker:28.1.1-dind` (Alpine) with conditional NVIDIA Container Toolkit support.

## Overview

**Base image:** `docker:28.1.1-dind` (Alpine Linux)

**Enhancement:** Custom entrypoint that installs NVIDIA Container Toolkit when `GPU_ENABLED=true` environment variable is set.

**Use case:** Enable GPU acceleration inside containers running the Docker daemon, allowing inner `docker run --gpus all` commands to access GPUs.

## Build

```bash
cd docker/
docker build -t zzaia-dind-nvidia:latest -f containers/dind/Dockerfile containers/dind/
```

## Usage

The image is activated in `docker-compose.yml` when `GPU_ENABLED=true` is passed to the compose override:

```bash
# CPU-only (uses standard docker:28.1.1-dind)
docker compose -f docker/docker-compose.yml -p workspace up -d

# With GPU support (uses custom dind image with toolkit)
docker compose -f docker/docker-compose.yml -f docker/docker-compose.gpu.yml -p workspace up -d
```

## How It Works

1. **Entrypoint script** (`entrypoint.sh`) runs before the Docker daemon starts
2. If `GPU_ENABLED=true`:
   - Downloads and installs NVIDIA Container Toolkit binaries (x86_64/arm64)
   - Verifies installation
3. Docker daemon starts normally with toolkit available
4. Workspace entrypoint can then configure the Docker runtime for GPU access

## Requirements

**Host:**
- NVIDIA drivers installed (`nvidia-smi` succeeds)
- NVIDIA Container Toolkit installed on host (`nvidia-container-toolkit` package)
- Native Docker Engine (not Docker Desktop, which blocks CDI injection)

**Container:**
- `GPU_ENABLED=true` environment variable
- GPU devices reserved in compose: `deploy.resources.reservations.devices`

## Limitations

- Alpine-based image uses pre-built NVIDIA Container Toolkit binaries
- Requires network access during container startup to download toolkit
- GPU support is conditional; CPU-only deployments have zero toolkit overhead

## Integration with Workspace

The workspace build system automatically selects this image when:
1. `GPU_ENABLED=true` in environment
2. `docker-compose.gpu.yml` override is applied
3. DinD service mounts this custom image instead of official `docker:28.1.1-dind`

See `/docker/docker-compose.yml` and `/docker/DOCKER.md` for full configuration.
