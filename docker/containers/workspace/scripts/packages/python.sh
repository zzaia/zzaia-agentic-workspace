#!/bin/bash
# packages/python.sh — Miniforge (conda) and Python package installation

set -euo pipefail

# ── Miniforge installation ────────────────────────────────────────────────────
python::install_miniforge() {
    if [ -x "$HOME/miniforge3/bin/conda" ]; then
        log_info "Miniforge already installed"
        return 0
    fi

    log_info "Installing Miniforge..."

    mkdir -p "$HOME/.local/share"
    curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
        -o /tmp/miniforge.sh

    bash /tmp/miniforge.sh -b -p "$HOME/miniforge3"
    rm /tmp/miniforge.sh

    # Initialize conda for bash
    "$HOME/miniforge3/bin/conda" init bash

    log_success "Miniforge installed"
}

# ── Python packages ──────────────────────────────────────────────────────────
python::install_packages() {
    log_info "Installing Python packages..."

    if [ ! -x "$HOME/miniforge3/bin/pip" ]; then
        log_warn "pip not found; skipping Python packages"
        return 0
    fi

    "$HOME/miniforge3/bin/pip" install --upgrade pip
    "$HOME/miniforge3/bin/pip" install \
        pypdf python-docx textual jinja2 graphviz diagrams \
        || log_warn "Some Python packages failed to install; continuing"

    log_success "Python packages installed"
}

# ── Conda environments ────────────────────────────────────────────────────────
python::install_conda_envs() {
    log_info "Creating conda environments..."

    if [ ! -x "$HOME/miniforge3/bin/conda" ]; then
        log_warn "conda not found; skipping environment creation"
        return 0
    fi

    "$HOME/miniforge3/bin/conda" create -n venv-analytics python=3.12 -y 2>/dev/null || true
    "$HOME/miniforge3/bin/conda" create -n venv-development python=3.12 -y 2>/dev/null || true

    log_success "Conda environments created"
}

# ── Verify Python installation ────────────────────────────────────────────────
python::verify() {
    log_info "Verifying Python installation..."

    local failed=0

    if ! [ -x "$HOME/miniforge3/bin/conda" ]; then
        log_warn "conda not available"
        failed=$((failed + 1))
    fi

    if ! [ -x "$HOME/miniforge3/bin/pip" ]; then
        log_warn "pip not available"
        failed=$((failed + 1))
    fi

    if [ $failed -eq 0 ]; then
        log_success "Python verification passed"
    else
        log_warn "Python verification: some tools not available"
    fi
}
