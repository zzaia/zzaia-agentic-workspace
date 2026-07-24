# Custom DinD (Docker-in-Docker) with NVIDIA Container Toolkit

This custom Docker-in-Docker image extends the official `docker:28.1.1-dind` (Alpine) with conditional NVIDIA Container Toolkit support.

## Overview

**Base image:** `docker:28.1.1-dind` (Alpine Linux)

**Enhancement:** Custom entrypoint that installs NVIDIA Container Toolkit when `GPU_ENABLED=true` environment variable is set.

**Use case:** Enable GPU acceleration inside containers running the Docker daemon, allowing inner `docker run --gpus all` commands to access GPUs.

## Build

Built via the Kubernetes image pipeline like every other `zzaia-*` image:

```bash
bash deploy/k8s/build-images.sh --list          # confirm the "dind" key
bash deploy/k8s/build-images.sh dind            # build + push just this image
```

(Manual equivalent: `docker build -t zzaia-dind-nvidia:latest -f containers/dind-server/Dockerfile containers/dind-server/`.)

## Usage

Deployed by `deploy/k8s/Chart/templates/dind-statefulset.yaml`. GPU support is
toggled by the chart's top-level `.Values.gpu.enabled` (see
`deploy/k8s/Chart/values.yaml`), which both sets this container's `GPU_ENABLED`
env var (still read by `entrypoint.sh` exactly as before) and gates
`runtimeClassName: nvidia` on the StatefulSet.

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
- `nvidia.com/gpu` resource limit + `runtimeClassName: nvidia`, both set by the
  chart when `.Values.gpu.enabled=true`

## Limitations

- Alpine-based image uses pre-built NVIDIA Container Toolkit binaries
- Requires network access during container startup to download toolkit
- GPU support is conditional; CPU-only deployments have zero toolkit overhead

## Integration with Workspace

This image is always used for `dind-server` — there is no separate CPU-only
base image to select between. Setting `.Values.gpu.enabled=true` in
`deploy/k8s/Chart/values.yaml` is what turns on the NVIDIA Container Toolkit
inside it (via `GPU_ENABLED`) and requests a GPU for the pod; leaving it
`false` (the default) keeps the same image with zero toolkit overhead.

See `deploy/k8s/Chart/templates/dind-statefulset.yaml` and
`docker/DOCKER.md`'s GPU Acceleration section for full configuration.
