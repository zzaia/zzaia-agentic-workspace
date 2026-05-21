#!/bin/bash
# jupyter-sidecar/entrypoint.sh — Runtime bootstrap for jupyter-sidecar with venv-analytics

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/tools}"
BOOTSTRAP_MARKER="$INSTALL_PREFIX/.bootstrap/venv-analytics.ready"
VERSIONS_FILE="${VERSIONS_FILE:-/opt/scripts/versions.env}"

if [ -f "$VERSIONS_FILE" ]; then
    source "$VERSIONS_FILE"
fi

log_info()    { echo "[jupyter-sidecar] $*"; }
log_success() { echo "[jupyter-sidecar] ✓ $*"; }
log_warn()    { echo "[jupyter-sidecar] ⚠ $*" >&2; }
log_error()   { echo "[jupyter-sidecar] ✗ $*" >&2; }

bootstrap_venv_analytics() {
    local conda="$INSTALL_PREFIX/miniforge3/bin/conda"
    local pip="$INSTALL_PREFIX/miniforge3/envs/venv-analytics/bin/pip"
    local py_ver="${PYTHON_VERSION:-3.12}"
    local script_hash
    script_hash=$(sha256sum "$0" | awk '{print $1}')

    if [ -f "$BOOTSTRAP_MARKER" ]; then
        local stored_hash
        stored_hash=$(cat "$BOOTSTRAP_MARKER" 2>/dev/null || echo "")
        if [ "$stored_hash" = "$script_hash" ]; then
            log_info "venv-analytics already bootstrapped (hash match)"
            return 0
        fi
        log_warn "Script changed — reinstalling venv-analytics"
    fi

    if [ ! -x "$conda" ]; then
        log_error "conda not found at $conda"
        return 1
    fi

    if ! "$conda" env list 2>/dev/null | grep -q "^venv-analytics"; then
        log_info "Creating venv-analytics conda environment with python=${py_ver}..."
        "$conda" create -n venv-analytics "python=${py_ver}" pip -y \
            || { log_error "conda create venv-analytics failed"; return 1; }
    else
        log_info "venv-analytics conda environment already exists"
    fi

    if [ ! -x "$pip" ]; then
        log_error "pip not found in venv-analytics at $pip"
        return 1
    fi

    log_info "Installing Jupyter packages..."
    "$pip" install --upgrade pip --quiet

    local jlab_spec="jupyterlab${JUPYTERLAB_VERSION:+==${JUPYTERLAB_VERSION}}"
    local notebook_spec="notebook${NOTEBOOK_VERSION:+==${NOTEBOOK_VERSION}}"
    local ipykernel_spec="ipykernel${IPYKERNEL_VERSION:+==${IPYKERNEL_VERSION}}"
    local kernel_gw_spec="jupyter-kernel-gateway${JUPYTER_KERNEL_GATEWAY_VERSION:+==${JUPYTER_KERNEL_GATEWAY_VERSION}}"

    "$pip" install \
        "$jlab_spec" "$notebook_spec" "$ipykernel_spec" "$kernel_gw_spec" \
        --quiet || { log_error "Jupyter packages failed"; return 1; }

    log_info "Installing data science packages..."
    local numpy_spec="numpy${NUMPY_VERSION:+==${NUMPY_VERSION}}"
    local pandas_spec="pandas${PANDAS_VERSION:+==${PANDAS_VERSION}}"
    local matplotlib_spec="matplotlib${MATPLOTLIB_VERSION:+==${MATPLOTLIB_VERSION}}"
    local scipy_spec="scipy${SCIPY_VERSION:+==${SCIPY_VERSION}}"
    local sklearn_spec="scikit-learn${SCIKIT_LEARN_VERSION:+==${SCIKIT_LEARN_VERSION}}"
    local seaborn_spec="seaborn${SEABORN_VERSION:+==${SEABORN_VERSION}}"
    local plotly_spec="plotly${PLOTLY_VERSION:+==${PLOTLY_VERSION}}"
    local ipywidgets_spec="ipywidgets${IPYWIDGETS_VERSION:+==${IPYWIDGETS_VERSION}}"
    local nbformat_spec="nbformat"

    "$pip" install \
        "$numpy_spec" "$pandas_spec" "$matplotlib_spec" "$scipy_spec" \
        "$sklearn_spec" "$seaborn_spec" "$plotly_spec" "$ipywidgets_spec" \
        "$nbformat_spec" \
        --quiet || { log_error "Data science packages failed"; return 1; }

    log_info "Registering ipykernel..."
    "$INSTALL_PREFIX/miniforge3/envs/venv-analytics/bin/python" -m ipykernel install \
        --user --name venv-analytics --display-name "Python (venv-analytics)" \
        2>/dev/null || log_warn "ipykernel registration had issues"

    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        log_info "Installing GPU/ML packages..."
        local torch_spec="torch${TORCH_VERSION:+==${TORCH_VERSION}}"
        local headroom_spec="headroom-ai[ml]${HEADROOM_AI_VERSION:+==${HEADROOM_AI_VERSION}}"

        "$pip" install \
            "$torch_spec" torchvision torchaudio \
            "$headroom_spec" \
            --index-url https://download.pytorch.org/whl/cu121 \
            --quiet || log_warn "GPU packages had installation issues; continuing"

        log_success "GPU packages installed"
    fi

    echo "$script_hash" > "$BOOTSTRAP_MARKER"
    log_success "venv-analytics bootstrap complete"
}

main() {
    log_info "Starting Jupyter Lab (GPU_ENABLED=${GPU_ENABLED:-false})..."

    bootstrap_venv_analytics

    local jupyter_bin="$INSTALL_PREFIX/miniforge3/envs/venv-analytics/bin/jupyter"
    if [ ! -x "$jupyter_bin" ]; then
        log_error "jupyter binary not found"
        exit 1
    fi

    local notebook_dir="/home/user/${WORKSPACE_NAME:-zzaia}"
    mkdir -p "$notebook_dir"

    log_info "Starting Jupyter Lab on port ${JUPYTER_PORT:-8888}..."
    exec "$jupyter_bin" lab \
        --ip=0.0.0.0 \
        --port="${JUPYTER_PORT:-8888}" \
        --no-browser \
        --NotebookApp.token='' \
        --NotebookApp.password='' \
        --notebook-dir="$notebook_dir"
}

main "$@"
