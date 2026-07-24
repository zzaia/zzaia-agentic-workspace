#!/usr/bin/env bash
# =============================================================================
# One-time bootstrap: make THIS repo self-deploying into the cluster the
# finance-data-engine repo provisions.
# =============================================================================
# The finance-data-engine repo carries zero agentic-workspace-specific
# manifests — this script is how the workspace repo wires itself into the
# already-running cluster without adding anything to that repo:
#   1. Apply the Fleet GitRepo CR so Fleet starts reconciling this repo's chart
#      (deploy/fleet/gitrepo.yaml -> deploy/k8s/Chart).
#   2. Configure the local *.workspace.zzaia.com dnsmasq wildcard on this host
#      (deploy/k8s/setup-workspace-dns.sh) so ad-hoc apps resolve immediately.
#   3. Print the remaining manual step (Key Vault secrets — see
#      deploy/k8s/AZURE_KEYVAULT.md) since it requires credentials this script
#      cannot and should not handle.
#
# Prerequisites (owned by finance-data-engine, not this script):
#   - A running cluster with Fleet, the shared infra namespace (Vault, SigNoz,
#     ESO + ClusterSecretStore, Kong) already up. See that repo's deploy/README.md.
#   - kubectl pointed at that cluster.
#
# Usage:
#   ./deploy/k8s/bootstrap.sh                 # gitops + dns (run on the k3s host)
#   ./deploy/k8s/bootstrap.sh --gitops-only    # apply the GitRepo CR only
#   ./deploy/k8s/bootstrap.sh --dns-only       # local DNS wildcard only
#   ./deploy/k8s/bootstrap.sh --skip-dns       # gitops only, e.g. from a remote workstation
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITREPO_FILE="${SCRIPT_DIR}/../fleet/gitrepo.yaml"
DNS_SCRIPT="${SCRIPT_DIR}/setup-workspace-dns.sh"
KEYVAULT_DOC="${SCRIPT_DIR}/AZURE_KEYVAULT.md"

DO_GITOPS=true
DO_DNS=true

log()  { printf '\033[0;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap] WARN:\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[0;32m[bootstrap] ✓\033[0m %s\n' "$*"; }
err()  { printf '\033[0;31m[bootstrap] ERROR:\033[0m %s\n' "$*" >&2; }

usage() { sed -n '2,24p' "$0"; }

for arg in "$@"; do
    case "$arg" in
        --gitops-only) DO_DNS=false ;;
        --dns-only) DO_GITOPS=false ;;
        --skip-dns) DO_DNS=false ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown flag: $arg"; usage; exit 1 ;;
    esac
done

# ── Step 1: Fleet GitRepo ────────────────────────────────────────────────────
bootstrap_gitops() {
    log "Checking kubectl connectivity..."
    if ! kubectl cluster-info >/dev/null 2>&1; then
        err "kubectl cannot reach a cluster. Point kubectl at the finance-data-engine-provisioned cluster first."
        return 1
    fi
    ok "cluster reachable ($(kubectl config current-context 2>/dev/null))"

    log "Checking Fleet is installed (namespace fleet-local)..."
    if ! kubectl get namespace fleet-local >/dev/null 2>&1; then
        err "namespace 'fleet-local' not found — Fleet is not installed on this cluster."
        err "Provision the cluster via the finance-data-engine repo first (deploy/local.sh)."
        return 1
    fi
    ok "Fleet is present"

    log "Applying ${GITREPO_FILE}..."
    kubectl apply -f "$GITREPO_FILE"
    ok "GitRepo applied — Fleet will clone this repo and reconcile deploy/k8s/Chart"

    log "Waiting briefly for Fleet to register the GitRepo..."
    sleep 3
    kubectl get gitrepo zzaia-agentic-workspace-local -n fleet-local 2>/dev/null || \
        warn "GitRepo not yet visible — check again shortly with: kubectl get gitrepo -n fleet-local"
}

# ── Step 2: local DNS wildcard ───────────────────────────────────────────────
bootstrap_dns() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "DNS setup needs root — re-invoking via sudo..."
        sudo "$DNS_SCRIPT"
    else
        "$DNS_SCRIPT"
    fi
}

main() {
    log "Bootstrapping zzaia-agentic-workspace into the cluster"
    local failed=false

    if $DO_GITOPS; then
        bootstrap_gitops || failed=true
    fi

    if $DO_DNS; then
        bootstrap_dns || failed=true
    fi

    echo
    if $failed; then
        err "One or more steps failed — see above. Nothing destructive was done; re-run after fixing."
        exit 1
    fi

    ok "Bootstrap complete."
    echo
    log "Remaining manual step — seed the nine Key Vault secrets this chart's"
    log "ExternalSecret expects (workspace pods will CrashLoop on missing values"
    log "until this is done). See: ${KEYVAULT_DOC}"
    echo
    log "Track the rollout with:"
    echo "    kubectl get gitrepo -n fleet-local zzaia-agentic-workspace-local -w"
    echo "    kubectl get pods -n zzaia-agentic-workspace -w"
}

main
