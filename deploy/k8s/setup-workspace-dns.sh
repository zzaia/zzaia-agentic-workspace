#!/usr/bin/env bash
# =============================================================================
# Local wildcard DNS for the agentic workspace: *.workspace.zzaia.com -> 127.0.0.1
# =============================================================================
# So ad-hoc apps under that domain resolve immediately with no re-run. Coexists
# with systemd-resolved (Ubuntu default owns 127.0.0.53:53) and with the
# finance-data-engine cluster's own DNS via split-DNS: dnsmasq binds an ALTERNATE
# loopback address and systemd-resolved routes ONLY *.workspace.zzaia.com to it.
# Port 53 is never contended — the resolvers listen on different loopback IPs, and
# the cluster repo's own fintech DNS (whatever mechanism it uses) is untouched.
#
# This lives in the agentic-workspace repo on purpose: the cluster provisioning
# repo (finance-data-engine) carries no workspace-specific host configuration.
#
# Idempotent. Run once on the host that runs the k3s node:
#   sudo ./deploy/k8s/setup-workspace-dns.sh
#   sudo ./deploy/k8s/setup-workspace-dns.sh --teardown
# =============================================================================
set -euo pipefail

LISTEN_ADDR="${WORKSPACE_DNS_LISTEN_ADDR:-127.0.0.55}"
DOMAINS=("workspace.zzaia.com")
DNSMASQ_CONF="/etc/dnsmasq.d/zzaia-workspace.conf"
RESOLVED_CONF="/etc/systemd/resolved.conf.d/zzaia-workspace.conf"

log() { printf '\033[0;34m[workspace-dns]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[workspace-dns] WARN:\033[0m %s\n' "$*" >&2; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "must run as root (sudo)"; exit 1
    fi
}

teardown() {
    require_root
    log "Removing workspace DNS configuration..."
    rm -f "$DNSMASQ_CONF" "$RESOLVED_CONF"
    systemctl reload systemd-resolved 2>/dev/null || warn "could not reload systemd-resolved"
    systemctl restart dnsmasq 2>/dev/null || warn "could not restart dnsmasq"
    log "Done. *.workspace.zzaia.com no longer resolved locally."
}

setup() {
    require_root
    log "Installing dnsmasq if absent..."
    if ! command -v dnsmasq >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            systemctl mask dnsmasq 2>/dev/null || true   # prevent auto-start on :53 before we configure it
            apt-get install -y dnsmasq
            systemctl unmask dnsmasq 2>/dev/null || true
        else
            warn "no apt-get; install dnsmasq manually then re-run"; exit 1
        fi
    fi

    log "Writing $DNSMASQ_CONF (dnsmasq binds $LISTEN_ADDR, leaving 127.0.0.53 to systemd-resolved)..."
    mkdir -p /etc/dnsmasq.d
    {
        echo "# Managed by deploy/k8s/setup-workspace-dns.sh — do not edit by hand."
        echo "listen-address=${LISTEN_ADDR}"
        echo "port=53"
        echo "bind-interfaces"
        echo "no-resolv"
        echo "no-poll"
        echo "cache-size=1000"
        for d in "${DOMAINS[@]}"; do echo "address=/${d}/127.0.0.1"; done
    } > "$DNSMASQ_CONF"

    log "Writing $RESOLVED_CONF (split-DNS: only workspace domains go to dnsmasq)..."
    mkdir -p /etc/systemd/resolved.conf.d
    {
        echo "# Managed by deploy/k8s/setup-workspace-dns.sh — do not edit by hand."
        echo "[Resolve]"
        echo "DNS=${LISTEN_ADDR}"
        for d in "${DOMAINS[@]}"; do echo "Domains=~${d}"; done
    } > "$RESOLVED_CONF"

    log "Restarting resolvers..."
    systemctl restart dnsmasq && systemctl enable dnsmasq >/dev/null 2>&1 || warn "dnsmasq restart/enable issue"
    systemctl restart systemd-resolved || warn "systemd-resolved restart issue"

    log "Verifying..."
    if command -v getent >/dev/null 2>&1; then
        getent hosts "test.workspace.zzaia.com" >/dev/null 2>&1 \
            && log "✓ *.workspace.zzaia.com resolves to 127.0.0.1" \
            || warn "resolution check did not return yet — may need a moment or a new shell"
    fi
    log "Done."
}

case "${1:-setup}" in
    --teardown|teardown) teardown ;;
    -h|--help) sed -n '2,20p' "$0" ;;
    *) setup ;;
esac
