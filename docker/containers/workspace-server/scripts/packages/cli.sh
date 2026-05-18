#!/bin/bash
# packages/cli.sh — Command-line tool installation (gh, k6, d2, dapr, rtk, az, tectonic)

set -euo pipefail

# ── GitHub CLI installation ───────────────────────────────────────────────────
cli::install_gh() {
    if command -v gh >/dev/null 2>&1; then
        log_info "GitHub CLI already installed"
        return 0
    fi

    log_info "Installing GitHub CLI..."

    mkdir -p "${INSTALL_PREFIX:-$HOME}/.local/bin"

    local gh_version="${GH_VERSION:-}"
    if [ -z "$gh_version" ]; then
        gh_version=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//') || true
    fi

    if [ -n "$gh_version" ]; then
        local gh_url="https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_amd64.tar.gz"
        curl -fsSL "$gh_url" | tar xz -C "${INSTALL_PREFIX:-$HOME}/.local/bin" "gh_${gh_version}_linux_amd64/bin/gh" --strip-components 2
        chmod +x "${INSTALL_PREFIX:-$HOME}/.local/bin/gh"
        log_success "GitHub CLI ${gh_version} installed"
    else
        log_warn "Could not determine gh version; skipping installation"
        return 0
    fi
}

# ── k6 load testing tool ──────────────────────────────────────────────────────
cli::install_k6() {
    if command -v k6 >/dev/null 2>&1; then
        log_info "k6 already installed"
        return 0
    fi

    log_info "Installing k6..."

    mkdir -p "${INSTALL_PREFIX:-$HOME}/.local/bin"

    local k6_version="${K6_VERSION:-}"
    if [ -z "$k6_version" ]; then
        k6_version=$(curl -fsSL https://api.github.com/repos/grafana/k6/releases/latest | grep '"tag_name"' | sed 's/.*v//;s/".*//') || true
    fi

    if [ -n "$k6_version" ]; then
        local k6_url="https://github.com/grafana/k6/releases/download/v${k6_version}/k6-v${k6_version}-linux-amd64.tar.gz"
        curl -fsSL "$k6_url" | tar xz -C "${INSTALL_PREFIX:-$HOME}/.local/bin" --strip-components 1 "k6-v${k6_version}-linux-amd64/k6" || log_warn "k6 download failed; continuing"
        [ -f "${INSTALL_PREFIX:-$HOME}/.local/bin/k6" ] && chmod +x "${INSTALL_PREFIX:-$HOME}/.local/bin/k6"
        log_success "k6 ${k6_version} installed"
    else
        log_warn "Could not determine k6 version; skipping installation"
        return 0
    fi
}

# ── D2 diagram tool ───────────────────────────────────────────────────────────
cli::install_d2() {
    if command -v d2 >/dev/null 2>&1 || [ -f "${INSTALL_PREFIX:-$HOME}/.local/bin/d2" ]; then
        log_info "D2 already installed"
        return 0
    fi

    log_info "Installing D2${D2_VERSION:+ ${D2_VERSION}}..."

    mkdir -p "${INSTALL_PREFIX:-$HOME}/.local/bin"

    local d2_version="${D2_VERSION:-}"
    if [ -z "$d2_version" ]; then
        d2_version=$(curl -fsSL https://api.github.com/repos/terrastruct/d2/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//') || true
    fi

    if [ -n "$d2_version" ]; then
        local d2_url="https://github.com/terrastruct/d2/releases/download/v${d2_version}/d2-v${d2_version}-linux-amd64.tar.gz"
        curl -fsSL "$d2_url" | tar xz -C "${INSTALL_PREFIX:-$HOME}/.local/bin" --strip-components 2 "d2-v${d2_version}/bin/d2" \
            || log_warn "D2 download failed; continuing"
        [ -f "${INSTALL_PREFIX:-$HOME}/.local/bin/d2" ] && chmod +x "${INSTALL_PREFIX:-$HOME}/.local/bin/d2" && log_success "D2 ${d2_version} installed" || log_warn "D2 binary not found after extraction"
    else
        log_warn "Could not determine D2 version; skipping installation"
    fi
}

# ── Dapr CLI ──────────────────────────────────────────────────────────────────
cli::install_dapr() {
    if [ -f "${INSTALL_PREFIX:-$HOME}/.local/bin/dapr" ]; then
        log_info "Dapr already installed"
        return 0
    fi

    log_info "Installing Dapr${DAPR_VERSION:+ ${DAPR_VERSION}}..."

    local dapr_dir="${INSTALL_PREFIX:-$HOME}/.local/bin"
    mkdir -p "$dapr_dir"

    # Use `env` to pass DAPR_INSTALL_DIR to the piped bash — prefix assignment
    # only applies to the curl process, not to the `bash` on the right of `|`.
    if [ -n "${DAPR_VERSION:-}" ]; then
        curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh \
            | env DAPR_INSTALL_DIR="$dapr_dir" DAPR_RELEASE_TAG="v${DAPR_VERSION}" bash \
            || log_warn "Dapr install failed; continuing"
    else
        curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh \
            | env DAPR_INSTALL_DIR="$dapr_dir" bash \
            || log_warn "Dapr install failed; continuing"
    fi

    log_success "Dapr installed to $dapr_dir"
}

# ── RTK (Rust Token Killer) ───────────────────────────────────────────────────
cli::install_rtk() {
    if command -v rtk >/dev/null 2>&1; then
        log_info "RTK already installed"
        return 0
    fi

    log_info "Installing RTK..."

    mkdir -p "${INSTALL_PREFIX:-$HOME}/.local/bin"

    local rtk_version="${RTK_VERSION:-}"
    if [ -z "$rtk_version" ]; then
        rtk_version=$(curl -fsSL https://api.github.com/repos/rtk-ai/rtk/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//') || true
    fi

    if [ -n "$rtk_version" ]; then
        local rtk_url="https://github.com/rtk-ai/rtk/releases/download/v${rtk_version}/rtk-x86_64-unknown-linux-musl.tar.gz"
        curl -fsSL "$rtk_url" | tar xz -C "${INSTALL_PREFIX:-$HOME}/.local/bin" rtk || log_warn "RTK download failed; continuing"
        [ -f "${INSTALL_PREFIX:-$HOME}/.local/bin/rtk" ] && chmod +x "${INSTALL_PREFIX:-$HOME}/.local/bin/rtk"
        log_success "RTK ${rtk_version} installed"
    else
        log_warn "Could not determine RTK version; skipping installation"
        return 0
    fi
}

# ── Azure CLI ─────────────────────────────────────────────────────────────────
cli::install_azure_cli() {
    if [ -f "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/az" ]; then
        log_info "Azure CLI already installed"
        return 0
    fi

    log_info "Installing Azure CLI via pip..."
    if [ -x "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/pip" ]; then
        "${INSTALL_PREFIX:-$HOME}/miniforge3/bin/pip" install azure-cli --quiet \
            && log_success "Azure CLI installed to miniforge" \
            || log_warn "Azure CLI install failed; skipping"
    else
        log_warn "miniforge pip not available; skipping Azure CLI"
    fi
}

# ── Tectonic LaTeX engine ─────────────────────────────────────────────────────
cli::install_tectonic() {
    if [ -f "${INSTALL_PREFIX:-$HOME}/.local/bin/tectonic" ]; then
        log_info "Tectonic already installed"
        return 0
    fi

    log_info "Installing Tectonic..."
    local tectonic_dir="${INSTALL_PREFIX:-$HOME}/.local/bin"
    mkdir -p "$tectonic_dir"

    local tectonic_version="${TECTONIC_VERSION:-}"
    if [ -z "$tectonic_version" ]; then
        tectonic_version=$(curl -fsSL https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest \
            | grep '"tag_name"' | sed 's/.*"tectonic@//;s/".*//') || true
    fi

    if [ -n "$tectonic_version" ]; then
        local tectonic_url="https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%40${tectonic_version}/tectonic-${tectonic_version}-x86_64-unknown-linux-musl.tar.gz"
        curl -fsSL "$tectonic_url" | tar xz -C "$tectonic_dir" tectonic \
            && chmod +x "$tectonic_dir/tectonic" \
            && log_success "Tectonic ${tectonic_version} installed" \
            || log_warn "Tectonic download failed; skipping"
    else
        log_warn "Could not determine Tectonic version; skipping"
    fi
}

# ── Verify CLI tools ──────────────────────────────────────────────────────────
cli::verify() {
    log_info "Verifying CLI tools..."

    local required_tools=("gh" "k6" "d2" "dapr" "rtk" "az" "tectonic")
    local failed=0

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warn "Tool not found: $tool"
            failed=$((failed + 1))
        fi
    done

    if [ $failed -eq 0 ]; then
        log_success "CLI tools verification passed"
    else
        log_warn "CLI tools verification: $failed tools not available"
    fi
}
