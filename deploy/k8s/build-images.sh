#!/usr/bin/env bash
###############################################################################
# ZZAIA Agentic Workspace — Kubernetes image build/push pipeline
#
# Builds every surviving zzaia-* image from docker/containers/*/Dockerfile using
# the exact build context the (legacy) docker-compose.yml used, tags each with an
# IMMUTABLE tag (the git short SHA) plus a moving alias, pushes both to the local
# OCI registry (127.0.0.1:5000 by default — see deploy/ansible/roles/registry),
# and emits a Helm values overlay (and matching --set-string snippet) that pins
# images.<name>.tag to the immutable tag so the release references exact images.
#
# This replaces `docker compose build`. Compose is retired (see docker/DOCKER.md).
#
# Exit codes: 0 ok | 1 usage/prereq | 2 build failure | 3 push failure
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# deploy/k8s -> deploy -> <repo root>
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CONTAINERS_DIR="${REPO_ROOT}/docker/containers"

# ---- Defaults (all overridable via flags / env) ----------------------------
REGISTRY="${REGISTRY:-localhost:5000}"
TAG="${TAG:-}"                 # empty => derive from git short SHA
ALIAS="${ALIAS:-latest}"       # moving alias, docker-pull convenience only
OVERLAY_FILE="${OVERLAY_FILE:-${SCRIPT_DIR}/Chart/values-images.yaml}"
DO_PUSH="true"
EMIT_SET_STRING="false"
declare -a DOCKER_CMD=(docker)
declare -a SELECTED=()

# ---- Image table -----------------------------------------------------------
# One row per surviving service:  <container-dir>|<values-key>|<repository>|<context>
#   context = root  -> build context is the repo root (compose `context: ..`)
#           = self  -> build context is the container dir  (compose dind case)
# vault-server, nginx-proxy, signoz-server, mcp-signoz, and mcp-newrelic are DROPPED.
# vault-server and nginx-proxy: cluster Vault + Kong Ingress replace them.
# signoz-server, mcp-signoz, mcp-newrelic: observability removed (deployed via AppHost instead).
# Repository names are copied verbatim from deploy/k8s/Chart/values.yaml — they are NOT
# mechanical from the directory name (portainer-server -> zzaia-portainer, database-qdrant -> zzaia-qdrant, ...).
IMAGES=(
  "dind-server|dind|zzaia/zzaia-dind-nvidia|self"
  "portainer-server|portainer|zzaia/zzaia-portainer|root"
  "workspace-server|workspaceServer|zzaia/zzaia-workspace-server|root"
  "bifrost-server|bifrostServer|zzaia/zzaia-bifrost-server|root"
  "ml-server|mlServer|zzaia/zzaia-ml-server|root"
  "database-qdrant|databaseQdrant|zzaia/zzaia-qdrant|root"
  "database-neo4j|databaseNeo4j|zzaia/zzaia-neo4j|root"
  "git-sidecar|gitSidecar|zzaia/zzaia-git-sidecar|root"
  "vscode-sidecar|vscodeSidecar|zzaia/zzaia-vscode-sidecar|root"
  "jupyter-sidecar|jupyterSidecar|zzaia/zzaia-jupyter-sidecar|root"
  "containers-dev-sidecar|containersDevSidecar|zzaia/zzaia-containers-dev-sidecar|root"
  "tunnel-sidecar|tunnelSidecar|zzaia/zzaia-tunnel-sidecar|root"
  "mcp-tavily|mcpTavily|zzaia/zzaia-mcp-tavily|root"
  "mcp-azure-devops|mcpAzureDevops|zzaia/zzaia-mcp-azure-devops|root"
  "mcp-postman|mcpPostman|zzaia/zzaia-mcp-postman|root"
  "mcp-github|mcpGithub|zzaia/zzaia-mcp-github|root"
  "mcp-aws-api|mcpAwsApi|zzaia/zzaia-mcp-aws-api|root"
  "mcp-azure-portal|mcpAzurePortal|zzaia/zzaia-mcp-azure-portal|root"
  "mcp-playwright|mcpPlaywright|zzaia/zzaia-mcp-playwright|root"
  "mcp-headroom|mcpHeadroom|zzaia/zzaia-mcp-headroom|root"
  "mcp-codegraph|mcpCodegraph|zzaia/zzaia-mcp-codegraph|root"
  "mcp-graphiti|mcpGraphiti|zzaia/zzaia-mcp-graphiti|root"
)

# ---- Output helpers --------------------------------------------------------
info()    { printf '\033[0;36m[INFO]\033[0m %s\n'    "$*"; }
success() { printf '\033[0;32m[OK]\033[0m %s\n'      "$*"; }
warn()    { printf '\033[0;33m[WARN]\033[0m %s\n'    "$*" >&2; }
error()   { printf '\033[0;31m[ERROR]\033[0m %s\n'   "$*" >&2; }

usage() {
  cat <<EOF
ZZAIA workspace — build & push Kubernetes images, then pin them in Helm values.

Usage: bash deploy/k8s/build-images.sh [OPTIONS] [IMAGE_KEY ...]

With no IMAGE_KEY the full set is built (22 images). Pass one or more Helm
values keys (e.g. mlServer mcpGithub) to build only those.

Options:
  -r, --registry HOST[:PORT]  Target registry (default: ${REGISTRY})
  -t, --tag TAG               Immutable tag (default: git short SHA, '.dirty'
                              suffix when the tree has uncommitted changes)
  -a, --alias ALIAS           Moving alias also pushed (default: ${ALIAS}).
                              Never referenced by Helm — the overlay pins the
                              immutable tag only.
  -o, --overlay FILE          Values overlay to write (default:
                              ${OVERLAY_FILE})
      --set-string            Also print a --set-string snippet to stdout
      --no-push               Build and tag only; skip registry push and, with
                              it, the overlay write
  -l, --list                  List the image keys and exit
  -h, --help                  Show this help and exit

Environment overrides: REGISTRY, TAG, ALIAS, OVERLAY_FILE.

Examples:
  bash deploy/k8s/build-images.sh
  bash deploy/k8s/build-images.sh --tag 1.2.3 mlServer mcpGithub
  REGISTRY=sjc.vultrcr.com/zzaia bash deploy/k8s/build-images.sh --alias prod

After a full run, deploy with the overlay pinning exact tags:
  helm upgrade --install zzaia-workspace deploy/k8s/Chart \\
    -n zzaia-agentic-workspace --create-namespace \\
    -f deploy/k8s/Chart/values.yaml \\
    -f deploy/k8s/Chart/values-production.yaml \\
    -f ${OVERLAY_FILE}
EOF
}

list_keys() {
  local row
  printf 'Image keys (values key -> repository):\n'
  for row in "${IMAGES[@]}"; do
    printf '  %-22s -> %s\n' "$(cut -d'|' -f2 <<<"${row}")" "$(cut -d'|' -f3 <<<"${row}")"
  done
}

# ---- Argument parsing ------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    -r|--registry) [ "$#" -ge 2 ] || { error "$1 needs a value"; exit 1; }; REGISTRY="$2"; shift 2 ;;
    --registry=*)  REGISTRY="${1#*=}"; shift ;;
    -t|--tag)      [ "$#" -ge 2 ] || { error "$1 needs a value"; exit 1; }; TAG="$2"; shift 2 ;;
    --tag=*)       TAG="${1#*=}"; shift ;;
    -a|--alias)    [ "$#" -ge 2 ] || { error "$1 needs a value"; exit 1; }; ALIAS="$2"; shift 2 ;;
    --alias=*)     ALIAS="${1#*=}"; shift ;;
    -o|--overlay)  [ "$#" -ge 2 ] || { error "$1 needs a value"; exit 1; }; OVERLAY_FILE="$2"; shift 2 ;;
    --overlay=*)   OVERLAY_FILE="${1#*=}"; shift ;;
    --set-string)  EMIT_SET_STRING="true"; shift ;;
    --no-push)     DO_PUSH="false"; shift ;;
    -l|--list)     list_keys; exit 0 ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; while [ "$#" -gt 0 ]; do SELECTED+=("$1"); shift; done ;;
    -*)            error "Unknown option '$1'"; usage; exit 1 ;;
    *)             SELECTED+=("$1"); shift ;;
  esac
done

# ---- Resolve tag (immutable) ----------------------------------------------
resolve_tag() {
  [ -n "${TAG}" ] && return 0
  if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
    error "Not a git repository and no --tag given; cannot derive an immutable tag."
    exit 1
  fi
  TAG="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
  if [ -n "$(git -C "${REPO_ROOT}" status --porcelain 2>/dev/null)" ]; then
    TAG="${TAG}.dirty"
    warn "Working tree is dirty — tagging '${TAG}'. Commit for a reproducible tag."
  fi
}

# ---- Docker availability ---------------------------------------------------
resolve_docker() {
  if docker info >/dev/null 2>&1; then
    DOCKER_CMD=(docker)
  elif sudo -n docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo docker)
    info "Docker group not active — using 'sudo docker'."
  else
    error "Cannot talk to the Docker daemon (tried 'docker' and 'sudo -n docker')."
    exit 1
  fi
}

# ---- Row lookup ------------------------------------------------------------
row_for_key() {
  local want="$1" row
  for row in "${IMAGES[@]}"; do
    [ "$(cut -d'|' -f2 <<<"${row}")" = "${want}" ] && { printf '%s\n' "${row}"; return 0; }
  done
  return 1
}

# ---- Build + push one image ------------------------------------------------
# Populates the BUILT_KEYS / BUILT_TAGS parallel arrays on success.
declare -a BUILT_KEYS=()
build_one() {
  local row="$1"
  local dir key repo ctx dockerfile context ref_immutable ref_alias
  dir="$(cut -d'|' -f1 <<<"${row}")"
  key="$(cut -d'|' -f2 <<<"${row}")"
  repo="$(cut -d'|' -f3 <<<"${row}")"
  ctx="$(cut -d'|' -f4 <<<"${row}")"

  dockerfile="${CONTAINERS_DIR}/${dir}/Dockerfile"
  if [ ! -f "${dockerfile}" ]; then
    error "Dockerfile not found for '${key}': ${dockerfile}"
    exit 2
  fi
  if [ "${ctx}" = "self" ]; then
    context="${CONTAINERS_DIR}/${dir}"
  else
    context="${REPO_ROOT}"
  fi

  ref_immutable="${REGISTRY}/${repo}:${TAG}"
  ref_alias="${REGISTRY}/${repo}:${ALIAS}"

  info "Building ${key} -> ${ref_immutable}"
  if ! "${DOCKER_CMD[@]}" build \
        -f "${dockerfile}" \
        -t "${ref_immutable}" \
        -t "${ref_alias}" \
        "${context}"; then
    error "Build failed for '${key}'."
    exit 2
  fi

  if [ "${DO_PUSH}" = "true" ]; then
    info "Pushing ${ref_immutable}"
    if ! "${DOCKER_CMD[@]}" push "${ref_immutable}"; then
      error "Push failed for ${ref_immutable}. Is the registry up? (deploy/ansible roles/registry: 127.0.0.1:5000)"
      exit 3
    fi
    info "Pushing ${ref_alias}"
    if ! "${DOCKER_CMD[@]}" push "${ref_alias}"; then
      error "Push failed for ${ref_alias}."
      exit 3
    fi
  fi

  BUILT_KEYS+=("${key}")
  success "Done ${key} (${TAG})"
}

# ---- Emit the values overlay ----------------------------------------------
write_overlay() {
  local out="$1" key
  {
    printf '# Generated by deploy/k8s/build-images.sh — DO NOT EDIT BY HAND.\n'
    printf '# Pins each built image to its immutable tag (git short SHA).\n'
    printf '# Regenerate: bash deploy/k8s/build-images.sh\n'
    printf '# Apply:      helm upgrade ... -f %s\n' "${out}"
    printf 'images:\n'
    printf '  registry: "%s"\n' "${REGISTRY}"
    for key in "${BUILT_KEYS[@]}"; do
      printf '  %s:\n    tag: "%s"\n' "${key}" "${TAG}"
    done
  } > "${out}"
  success "Wrote values overlay: ${out}"
}

emit_set_string() {
  local key
  printf '\n# --set-string snippet (alternative to the overlay file):\n'
  printf -- '  --set-string images.registry=%s \\\n' "${REGISTRY}"
  for key in "${BUILT_KEYS[@]}"; do
    printf -- '  --set-string images.%s.tag=%s \\\n' "${key}" "${TAG}"
  done
  printf -- '  # (drop the trailing backslash on the final line)\n'
}

# ---- Main ------------------------------------------------------------------
main() {
  resolve_tag
  resolve_docker

  local -a rows=()
  if [ "${#SELECTED[@]}" -gt 0 ]; then
    local want row
    for want in "${SELECTED[@]}"; do
      if ! row="$(row_for_key "${want}")"; then
        error "Unknown image key '${want}'. Run --list to see valid keys."
        exit 1
      fi
      rows+=("${row}")
    done
  else
    rows=("${IMAGES[@]}")
  fi

  info "Registry: ${REGISTRY}"
  info "Immutable tag: ${TAG}   Moving alias: ${ALIAS}"
  info "Images to build: ${#rows[@]}   Push: ${DO_PUSH}"
  echo ""

  local row
  for row in "${rows[@]}"; do
    build_one "${row}"
  done

  echo ""
  if [ "${DO_PUSH}" = "true" ]; then
    write_overlay "${OVERLAY_FILE}"
    [ "${EMIT_SET_STRING}" = "true" ] && emit_set_string
  else
    warn "--no-push set: skipped registry push and overlay write."
  fi

  echo ""
  success "Built ${#BUILT_KEYS[@]} image(s) at tag ${TAG}."
}

main
