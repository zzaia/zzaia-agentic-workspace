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

# ── Conda environments ────────────────────────────────────────────────────────
python::install_conda_envs() {
    log_info "Creating conda environments..."

    if [ ! -x "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda" ]; then
        log_warn "conda not found; skipping environment creation"
        return 0
    fi

    local py_ver="${CONDA_PYTHON_VERSION:-3.12}"
    "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda" create -n venv-analytics "python=${py_ver}" -y 2>/dev/null || true
    "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda" create -n venv-development "python=${py_ver}" -y 2>/dev/null || true

    log_success "Conda environments created"
}

# ── GPU / ML packages ────────────────────────────────────────────────────────
python::install_gpu_packages() {
    if [ "${GPU_ENABLED:-false}" != "true" ]; then
        log_info "GPU_ENABLED not set — skipping GPU package installation"
        return 0
    fi

    log_info "Installing GPU/ML packages into venv-analytics..."

    local conda="${INSTALL_PREFIX:-$HOME}/miniforge3/bin/conda"
    local pip="${INSTALL_PREFIX:-$HOME}/miniforge3/envs/venv-analytics/bin/pip"

    if [ ! -x "$conda" ]; then
        log_warn "conda not found; skipping GPU packages"
        return 0
    fi

    # Ensure venv-analytics exists
    "$conda" create -n venv-analytics "python=${CONDA_PYTHON_VERSION:-3.12}" -y 2>/dev/null || true

    "$pip" install --upgrade pip

    local torch_spec="torch${TORCH_VERSION:+==${TORCH_VERSION}}"
    local headroom_spec="headroom-ai[ml]${HEADROOM_AI_VERSION:+==${HEADROOM_AI_VERSION}}"
    local jupyter_spec="jupyter${JUPYTER_VERSION:+==${JUPYTER_VERSION}}"
    local jupyterlab_spec="jupyterlab${JUPYTERLAB_VERSION:+==${JUPYTERLAB_VERSION}}"
    local ipykernel_spec="ipykernel${IPYKERNEL_VERSION:+==${IPYKERNEL_VERSION}}"
    local numpy_spec="numpy${NUMPY_VERSION:+==${NUMPY_VERSION}}"
    local pandas_spec="pandas${PANDAS_VERSION:+==${PANDAS_VERSION}}"
    local sklearn_spec="scikit-learn${SCIKIT_LEARN_VERSION:+==${SCIKIT_LEARN_VERSION}}"
    local matplotlib_spec="matplotlib${MATPLOTLIB_VERSION:+==${MATPLOTLIB_VERSION}}"

    "$pip" install \
        "$torch_spec" torchvision torchaudio \
        "$headroom_spec" fastapi uvicorn "httpx[http2]" \
        "$jupyter_spec" "$jupyterlab_spec" "$ipykernel_spec" \
        "$numpy_spec" "$pandas_spec" "$sklearn_spec" "$matplotlib_spec" \
        || log_warn "Some GPU packages failed to install; continuing"

    # Register venv-analytics as a Jupyter kernel
    "${INSTALL_PREFIX:-$HOME}/miniforge3/envs/venv-analytics/bin/python" \
        -m ipykernel install --user --name ml-runtime --display-name "ML Runtime (GPU)" 2>/dev/null || true

    log_success "GPU/ML packages installed into venv-analytics"
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

    if [ $failed -eq 0 ]; then
        log_success "Python verification passed"
    else
        log_warn "Python verification: some tools not available"
    fi
}

# ── Verify GPU packages ───────────────────────────────────────────────────────
python::verify_gpu() {
    if [ "${GPU_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    log_info "Verifying GPU packages..."

    local python="${INSTALL_PREFIX:-$HOME}/miniforge3/envs/venv-analytics/bin/python"

    if ! [ -x "$python" ]; then
        log_warn "venv-analytics python not found"
        return 1
    fi

    "$python" -c "import torch; print('torch:', torch.__version__)" 2>/dev/null \
        && log_success "PyTorch available in venv-analytics" \
        || log_warn "PyTorch import failed"
}
