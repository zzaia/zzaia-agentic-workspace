#!/bin/bash
# packages/python.sh — Miniforge (conda) and Python package installation

set -euo pipefail

# ── Miniforge installation ────────────────────────────────────────────────────
python::install_miniforge() {
    if [ -x "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda" ]; then
        log_info "Miniforge already installed"
        return 0
    fi

    log_info "Installing Miniforge..."

    mkdir -p "${INSTALL_PREFIX:-$HOME}/.local/share"
    curl -fsSL "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${MINIFORGE_ARCH}.sh" \
        -o /tmp/miniforge.sh

    bash /tmp/miniforge.sh -b -p "${INSTALL_PREFIX:-$HOME}/miniforge3"
    rm /tmp/miniforge.sh

    # Initialize conda for bash
    "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda" init bash

    log_success "Miniforge installed"
}

# ── CUDA runtime installation (shared via conda) ──────────────────────────────
python::install_cuda() {
    if [ "${GPU_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    log_info "Installing CUDA runtime via conda (GPU_ENABLED=true)..."

    local conda="${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda"

    if [ ! -x "$conda" ]; then
        log_warn "conda not found; skipping CUDA install"
        return 0
    fi

    "$conda" install -c nvidia \
        "cuda-runtime=${CUDA_VERSION:-12.1}" \
        "cuda-nvcc=${CUDA_VERSION:-12.1}" \
        -n base -y --quiet \
        || log_warn "CUDA conda install had issues; continuing"

    log_success "CUDA runtime installed into conda base env"
}

# ── Python packages ──────────────────────────────────────────────────────────
python::install_packages() {
    log_info "Installing Python packages..."

    if [ ! -x "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/pip" ]; then
        log_warn "pip not found; skipping Python packages"
        return 0
    fi

    "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/pip" install --upgrade pip

    # Build versioned package specs — empty version var means install latest
    local pypdf_spec="pypdf${PYPDF_VERSION:+==${PYPDF_VERSION}}"
    local docx_spec="python-docx${PYTHON_DOCX_VERSION:+==${PYTHON_DOCX_VERSION}}"
    local textual_spec="textual${TEXTUAL_VERSION:+==${TEXTUAL_VERSION}}"
    local jinja2_spec="jinja2${JINJA2_VERSION:+==${JINJA2_VERSION}}"
    local graphviz_spec="graphviz${GRAPHVIZ_VERSION:+==${GRAPHVIZ_VERSION}}"
    local diagrams_spec="diagrams${DIAGRAMS_VERSION:+==${DIAGRAMS_VERSION}}"

    "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/pip" install \
        "$pypdf_spec" "$docx_spec" "$textual_spec" \
        "$jinja2_spec" "$graphviz_spec" "$diagrams_spec" \
        || log_warn "Some Python packages failed to install; continuing"

    log_success "Python packages installed"
}

# ── Development environment (API development packages) ───────────────────────
python::install_venv_development() {
    log_info "Installing venv-development with API development packages..."

    local conda="${INSTALL_PREFIX:-/opt/tools}/miniforge3/bin/conda"
    local pip="${INSTALL_PREFIX:-/opt/tools}/miniforge3/envs/venv-development/bin/pip"

    if [ ! -x "$conda" ]; then
        log_warn "conda not found; skipping venv-development setup"
        return 0
    fi

    if ! "$conda" env list 2>/dev/null | grep -q "^venv-development"; then
        "$conda" create -n venv-development "python=${CONDA_PYTHON_VERSION:-3.12}" pip -y \
            || { log_warn "conda create venv-development failed"; return 1; }
    fi

    if [ ! -x "$pip" ]; then
        log_warn "pip not found in venv-development"
        return 1
    fi

    "$pip" install --upgrade pip --quiet

    local fastapi_spec="fastapi${FASTAPI_VERSION:+==${FASTAPI_VERSION}}"
    local uvicorn_spec="uvicorn[standard]${UVICORN_VERSION:+==${UVICORN_VERSION}}"
    local pydantic_spec="pydantic${PYDANTIC_VERSION:+==${PYDANTIC_VERSION}}"
    local httpx_spec="httpx${HTTPX_VERSION:+==${HTTPX_VERSION}}"
    local sqlalchemy_spec="sqlalchemy${SQLALCHEMY_VERSION:+==${SQLALCHEMY_VERSION}}"
    local alembic_spec="alembic${ALEMBIC_VERSION:+==${ALEMBIC_VERSION}}"

    "$pip" install \
        "$fastapi_spec" "$uvicorn_spec" "$pydantic_spec" \
        "$httpx_spec" "httpx[http2]" \
        "$sqlalchemy_spec" "$alembic_spec" \
        "python-jose[cryptography]" "passlib[bcrypt]" \
        python-multipart aiofiles \
        typer loguru python-dotenv \
        pytest pytest-asyncio \
        --quiet || log_warn "Some venv-development packages failed to install; continuing"

    log_success "venv-development configured with API development packages"
}

# ── Verify Python installation ────────────────────────────────────────────────
python::verify() {
    log_info "Verifying Python installation..."

    local failed=0

    if ! [ -x "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda" ]; then
        log_warn "conda not available"
        failed=$((failed + 1))
    fi

    if ! [ -x "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/pip" ]; then
        log_warn "pip not available"
        failed=$((failed + 1))
    fi

    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        if ! [ -f "${INSTALL_PREFIX:-$HOME}/miniforge3/lib/libcudart.so.12" ]; then
            log_warn "CUDA runtime not found (GPU_ENABLED=true but libcudart.so.12 missing)"
            failed=$((failed + 1))
        fi
    fi

    if [ $failed -eq 0 ]; then
        log_success "Python verification passed"
    else
        log_warn "Python verification: some tools not available"
    fi
}

