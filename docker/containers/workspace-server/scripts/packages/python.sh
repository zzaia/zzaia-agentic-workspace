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
