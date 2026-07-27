#!/usr/bin/env bash

################################################################################
# ZZAIA Agentic Workspace - Local Kubernetes Deployment Script
#
# Sets up a complete local Kubernetes environment using a single-node k3s cluster,
# provisions bootstrap infrastructure (Kong ingress, ESO, Fleet), deploys workloads
# via Fleet pull-mode, and manages secrets via Bitwarden Secrets Manager.
#
# Usage: bash deploy/local.sh [up|host|app|reset|pause|resume|teardown]
#
# Make executable: chmod +x deploy/local.sh
#
# Exit codes:
#   0 = Success
#   1 = Prerequisite failure (missing tools)
#   2 = Cluster setup failure
#   3 = Deployment failure
################################################################################

set -euo pipefail

# Configuration
readonly NAMESPACE="zzaia-agentic-workspace"
readonly CLUSTER_NAME="zzaia-local"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CHART_DIR="${SCRIPT_DIR}/k8s/Chart"

# TLS configuration — self-signed wildcard for local development
readonly WILDCARD_TLS_SECRET="zzaia-workspace-tls"
readonly WILDCARD_TLS_DOMAIN="workspace.zzaia.com"

# Bitwarden Secrets Manager configuration
readonly ESO_NAMESPACE="external-secrets"
readonly BWS_TOKEN_SECRET="bitwarden-access-token"

# Kong ingress configuration
readonly KONG_HTTPS_HOST_PORT=8443
readonly KONG_HTTPS_NODE_PORT=30443

# Color output helpers
info() {
    echo -e "\033[0;36m[INFO]\033[0m $*"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

warn() {
    echo -e "\033[0;33m[WARN]\033[0m $*"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*"
}

################################################################################
# SECTION 1: Prerequisite Check
################################################################################

check_prerequisites() {
    info "Checking prerequisites..."

    if ! command -v ansible-playbook &> /dev/null; then
        error "Missing required tool: ansible-playbook"
        echo ""
        echo "Ansible is the only host prerequisite — the playbook installs everything"
        echo "else (docker, kubectl, helm, k3s, the local registry and the bootstrap"
        echo "ring). Install it with:"
        echo "  apt install ansible-core   (or)   pipx install --include-deps ansible-core"
        exit 1
    fi

    info "ansible-playbook: $(ansible-playbook --version 2>/dev/null | head -n 1 || echo 'unknown')"
    success "Prerequisite met (ansible-playbook)"
}

################################################################################
# SECTION 2: Bitwarden Secrets Manager Token Configuration
################################################################################

configure_bws_token() {
    BWS_ACCESS_TOKEN="${BWS_ACCESS_TOKEN:-}"

    if [ "${NO_BWS:-false}" = "true" ]; then
        info "Skipping Bitwarden Secrets Manager (NO_BWS=true)"
        return
    fi

    if [ -z "${BWS_ACCESS_TOKEN}" ] && [ -t 0 ]; then
        read -r -s -p "Bitwarden Secrets Manager Access Token (press Enter to skip): " BWS_ACCESS_TOKEN
        echo ""
    fi

    if [ -z "${BWS_ACCESS_TOKEN}" ]; then
        warn "No Bitwarden Secrets Manager token provided — workspace secrets must be configured manually later"
        return
    fi

    export BWS_ACCESS_TOKEN
    success "Bitwarden Secrets Manager token configured"
}

################################################################################
# SECTION 3: Host Provisioning (Ansible)
################################################################################

provision_host() {
    info "Running Ansible provisioning (k3s, registry, Kong, Fleet, ESO)..."

    if ! command -v kubectl &> /dev/null; then
        info "Installing Ansible collection requirements..."
        ansible-galaxy collection install -r "${SCRIPT_DIR}/ansible/requirements.yml" --force
    fi

    local become_flag=""
    if ! sudo -n true 2>/dev/null; then
        info "Passwordless sudo not available — Ansible will prompt for BECOME password..."
        become_flag="--ask-become-pass"
    fi

    info "Running site.yml playbook..."
    local extra_vars="-e kubeconfig_path=/etc/rancher/k3s/k3s.yaml"
    if [ "${NO_BWS:-false}" = "true" ]; then
        extra_vars="${extra_vars} -e deploy_bitwarden_sdk=false"
    fi
    ansible-playbook \
        -i "${SCRIPT_DIR}/ansible/inventory.ini" \
        "${SCRIPT_DIR}/ansible/site.yml" \
        ${extra_vars} \
        ${become_flag} \
        || { error "Ansible provisioning failed"; exit 2; }

    success "Host provisioning complete"
}

################################################################################
# SECTION 4: Kubeconfig Setup
################################################################################

setup_kubeconfig() {
    info "Setting up kubeconfig..."

    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

    # Wait for the cluster to be ready
    info "Waiting for cluster to be ready..."
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if kubectl cluster-info &>/dev/null; then
            success "Cluster is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    error "Cluster did not become ready in time"
    exit 2
}

################################################################################
# SECTION 5: TLS Certificate Configuration
################################################################################

configure_tls_certificate() {
    info "Creating self-signed TLS certificate for ${WILDCARD_TLS_DOMAIN}..."

    # Check if secret already exists
    if kubectl get secret "${WILDCARD_TLS_SECRET}" -n "${NAMESPACE}" &>/dev/null 2>&1; then
        warn "TLS secret already exists, skipping creation"
        return
    fi

    # Generate self-signed certificate (valid for 365 days)
    local cert_file="/tmp/tls.crt"
    local key_file="/tmp/tls.key"

    openssl req -x509 -newkey rsa:2048 -keyout "${key_file}" -out "${cert_file}" \
        -days 365 -nodes -subj "/CN=${WILDCARD_TLS_DOMAIN}" \
        -addext "subjectAltName=DNS:${WILDCARD_TLS_DOMAIN},DNS:*.${WILDCARD_TLS_DOMAIN}" 2>/dev/null

    # Create the secret
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret tls "${WILDCARD_TLS_SECRET}" \
        --cert="${cert_file}" \
        --key="${key_file}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -

    rm -f "${cert_file}" "${key_file}"
    success "TLS certificate configured"
}

################################################################################
# SECTION 5B: Bitwarden SDK Server Certificate Configuration
################################################################################

configure_bws_tls_certificate() {
    if [ "${NO_BWS:-false}" = "true" ]; then
        info "Skipping bitwarden-sdk-server TLS certificate (NO_BWS=true)"
        return
    fi

    info "Generating self-signed TLS certificate for bitwarden-sdk-server..."

    local temp_dir="/tmp/bws-certs-$$"
    mkdir -p "${temp_dir}"
    trap "rm -rf ${temp_dir}" RETURN

    # Generate private key
    openssl genrsa -out "${temp_dir}/bws-server.key" 2048 2>/dev/null

    # Generate CSR with SANs for all possible service DNS names
    openssl req -new \
        -key "${temp_dir}/bws-server.key" \
        -out "${temp_dir}/bws-server.csr" \
        -subj "/CN=external-secrets-bitwarden-sdk-server.external-secrets.svc.cluster.local" \
        -addext "subjectAltName=DNS:external-secrets-bitwarden-sdk-server.external-secrets.svc.cluster.local,DNS:external-secrets-bitwarden-sdk-server.external-secrets.svc,DNS:external-secrets-bitwarden-sdk-server,DNS:bitwarden-sdk-server.external-secrets.svc.cluster.local,DNS:localhost" 2>/dev/null

    # Self-sign the certificate for 365 days
    openssl x509 -req -days 365 \
        -in "${temp_dir}/bws-server.csr" \
        -signkey "${temp_dir}/bws-server.key" \
        -out "${temp_dir}/bws-server.crt" \
        -extfile <(printf "subjectAltName=DNS:external-secrets-bitwarden-sdk-server.external-secrets.svc.cluster.local,DNS:external-secrets-bitwarden-sdk-server.external-secrets.svc,DNS:external-secrets-bitwarden-sdk-server,DNS:bitwarden-sdk-server.external-secrets.svc.cluster.local,DNS:localhost") 2>/dev/null

    # Store certificate and key for Helm values (base64 encoded, with newlines removed for JSON)
    export BWS_TLS_CRT=$(base64 -w0 < "${temp_dir}/bws-server.crt")
    export BWS_TLS_KEY=$(base64 -w0 < "${temp_dir}/bws-server.key")

    # Extract the certificate for caBundle (for ESO to trust it)
    export BWS_CA_BUNDLE=$(cat "${temp_dir}/bws-server.crt")

    # Create values-local.yaml for Fleet deployments with the caBundle
    info "Creating values-local.yaml for Fleet deployment..."
    cat > "${CHART_DIR}/values-local.yaml" <<EOF
# Bitwarden SDK server TLS caBundle (auto-generated by deploy/local.sh)
externalSecrets:
  bitwardensecretsmanager:
    caBundle: |
EOF
    # Indent the certificate for YAML readability
    sed 's/^/      /' "${temp_dir}/bws-server.crt" >> "${CHART_DIR}/values-local.yaml"

    success "Bitwarden SDK server TLS certificate generated"
}

################################################################################
# SECTION 6: Bitwarden Access Token Secret
################################################################################

configure_bws_secret() {
    if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
        warn "Skipping Bitwarden token secret (no token provided)"
        return
    fi

    info "Creating Bitwarden access token secret in ${ESO_NAMESPACE}..."

    # Create the external-secrets namespace if needed
    kubectl create namespace "${ESO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

    # Create or update the secret
    kubectl create secret generic "${BWS_TOKEN_SECRET}" \
        --from-literal=credentials="${BWS_ACCESS_TOKEN}" \
        -n "${ESO_NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -

    success "Bitwarden access token secret configured"
}

################################################################################
# SECTION 7: Build and Push Container Images
################################################################################

build_and_push_images() {
    info "Building and pushing container images to local registry..."

    if ! command -v docker &> /dev/null; then
        error "Docker is not available — host provisioning may have failed"
        exit 2
    fi

    # Build and push images
    bash "${SCRIPT_DIR}/k8s/build-images.sh" || {
        error "Image build/push failed"
        exit 2
    }

    success "Container images built and pushed"
}

################################################################################
# SECTION 8: Deploy Application
################################################################################

deploy_via_helm() {
    info "Deploying application via Helm (validation mode, no Fleet)..."

    local helm_args=(
        "upgrade" "--install" "zzaia-workspace" "${CHART_DIR}"
        "-n" "${NAMESPACE}"
        "--create-namespace"
        "-f" "${CHART_DIR}/values.yaml"
        "-f" "${CHART_DIR}/values-images.yaml"
        "--set" "externalSecrets.enabled=false"
        "--set" "ingress.tls.certManager=false"
        "--set" "priorityClass.create=true"
        "--set" "images.registry=localhost:5000"
    )

    # If BWS TLS cert is available, pass it to Helm
    if [ -n "${BWS_CA_BUNDLE:-}" ]; then
        # Escape caBundle for JSON/YAML (replace newlines with \n)
        local ca_bundle_escaped=$(echo "${BWS_CA_BUNDLE}" | sed 's/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')
        helm_args+=("--set" "externalSecrets.bitwardensecretsmanager.caBundle=${ca_bundle_escaped}")
    fi

    helm "${helm_args[@]}" || {
        error "Helm deployment failed"
        exit 3
    }

    success "Helm deployment complete"
}

deploy_via_fleet() {
    info "Deploying application via Fleet..."

    # Label the local cluster for Fleet targeting
    info "Labeling local cluster with env=local..."
    kubectl label nodes --all env=local --overwrite

    # Apply the GitRepo
    info "Applying Fleet GitRepo..."
    kubectl apply -f "${SCRIPT_DIR}/fleet/gitrepo.yaml" || {
        error "Failed to apply Fleet GitRepo"
        exit 3
    }

    # Wait for Fleet to process the GitRepo
    info "Waiting for Fleet to reconcile the GitRepo..."
    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get gitrepo -n fleet-local &>/dev/null; then
            success "Fleet GitRepo deployed"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    warn "Fleet GitRepo may still be reconciling — monitor with: kubectl -n fleet-local get gitrepo -w"
}

################################################################################
# SECTION 9: Summary and Access Information
################################################################################

print_summary() {
    info "Deployment complete!"
    echo ""
    echo "================================================================================"
    if [ "${NO_BWS:-false}" = "true" ]; then
        echo "ZZAIA Agentic Workspace - VALIDATION MODE (No Bitwarden Token)"
        echo "================================================================================"
        echo ""
        echo "STATUS: Running with fallback dev secrets (no BWS/ESO sync)."
        echo "        To enable real secrets, provide a Bitwarden token:"
        echo "          export BWS_ACCESS_TOKEN=<token>"
        echo "          bash deploy/local.sh up"
    else
        echo "ZZAIA Agentic Workspace - Local Kubernetes Deployment"
        echo "================================================================================"
    fi
    echo ""
    echo "Cluster: ${CLUSTER_NAME}"
    echo "Namespace: ${NAMESPACE}"
    echo ""
    echo "Access Information (via Kong HTTPS on port ${KONG_HTTPS_HOST_PORT}):"
    echo "  - ML Server (public):   https://headroom.${WILDCARD_TLS_DOMAIN}:${KONG_HTTPS_HOST_PORT}"
    echo ""
    echo "Kubernetes Pods:"
    echo ""
    kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | sed 's/^/  /' || echo "  (waiting for pods to initialize)"
    echo ""
    echo "Fleet Status:"
    echo ""
    kubectl get gitrepo -n fleet-local --no-headers 2>/dev/null | sed 's/^/  /' || echo "  (waiting for GitRepo)"
    echo ""
    echo "Useful Commands:"
    echo "  # View application logs"
    echo "  kubectl logs -n ${NAMESPACE} -l app=ml-server"
    echo ""
    if [ "${NO_BWS:-false}" != "true" ]; then
        echo "  # Watch Fleet reconciliation"
        echo "  kubectl -n fleet-local get gitrepo -w"
        echo ""
    fi
    echo "  # Port forward to local services"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/ml-server 8787:8787"
    echo ""
    echo "  # Get all resources in namespace"
    echo "  kubectl get all -n ${NAMESPACE}"
    echo ""
    if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
        echo "Secrets:"
        echo "  Bitwarden Secrets Manager token was NOT configured."
        echo "  External Secrets will fail to sync. To enable:"
        echo "    export BWS_ACCESS_TOKEN=<your-token>"
        echo "    kubectl create secret generic ${BWS_TOKEN_SECRET} \\"
        echo "      --from-literal=credentials=\${BWS_ACCESS_TOKEN} \\"
        echo "      -n ${ESO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
        echo ""
    fi
    echo "================================================================================"
    echo ""
}

################################################################################
# RESET (keep bootstrap ring, delete apps)
################################################################################

reset() {
    warn "This will remove all deployed apps and workload state (bootstrap ring stays installed)"

    info "Deleting Fleet GitRepo(s) from fleet-local namespace..."
    if kubectl delete gitrepo --all -n fleet-local --ignore-not-found=true 2>/dev/null; then
        success "GitRepo(s) deleted"
    fi

    info "Deleting application namespace..."
    if kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true 2>/dev/null; then
        success "Application namespace deleted"
    fi

    success "Reset complete — bootstrap ring remains installed"
}

################################################################################
# PAUSE (scale workloads to zero)
################################################################################

pause() {
    info "Pausing workloads (scaling StatefulSets/Deployments to zero)..."

    kubectl scale statefulset -n "${NAMESPACE}" --all --replicas=0 2>/dev/null || true
    kubectl scale deployment -n "${NAMESPACE}" --all --replicas=0 2>/dev/null || true

    success "Workloads paused"
}

################################################################################
# RESUME (scale workloads back up)
################################################################################

resume() {
    info "Resuming workloads..."
    # This is best-effort — let Fleet reconcile
    kubectl rollout restart -n "${NAMESPACE}" statefulset --all 2>/dev/null || true
    success "Workloads resumed (check Fleet status with: kubectl -n fleet-local get gitrepo -w)"
}

################################################################################
# TEARDOWN (remove entire cluster)
################################################################################

teardown() {
    error "TEARDOWN: This will completely remove the k3s cluster, including all bootstrap infrastructure"
    read -r -p "Are you SURE? Type 'yes' to confirm: " confirm
    if [ "${confirm}" != "yes" ]; then
        info "Teardown cancelled"
        return
    fi

    info "Stopping k3s service..."
    sudo systemctl stop k3s || true

    info "Removing k3s installation..."
    sudo /usr/local/bin/k3s-uninstall.sh || sudo rm -rf /etc/rancher /var/lib/rancher /usr/local/bin/k3s* || true

    info "Stopping local registry..."
    docker stop zzaia-registry 2>/dev/null || true
    docker rm zzaia-registry 2>/dev/null || true

    info "Stopping dnsmasq..."
    sudo systemctl stop dnsmasq || true

    success "Teardown complete"
}

################################################################################
# MAIN ORCHESTRATION
################################################################################

run_host() {
    check_prerequisites
    provision_host
    setup_kubeconfig
}

run_app() {
    setup_kubeconfig
    configure_tls_certificate
    configure_bws_tls_certificate
    if [ "${NO_BWS:-false}" = "true" ]; then
        build_and_push_images
        deploy_via_helm
    else
        configure_bws_secret
        build_and_push_images
        deploy_via_fleet
    fi
}

run_up() {
    check_prerequisites
    provision_host
    setup_kubeconfig
    configure_tls_certificate
    configure_bws_tls_certificate
    configure_bws_token

    if [ "${NO_BWS:-false}" = "true" ]; then
        build_and_push_images
        deploy_via_helm
    else
        configure_bws_secret
        build_and_push_images
        deploy_via_fleet
    fi

    print_summary
}

main() {
    local command="${1:-up}"

    # Parse options before the command
    while [ "$#" -gt 0 ] && [[ "$1" == -* ]]; do
        case "$1" in
            --no-bws) NO_BWS="true"; shift ;;
            -h|--help) usage; exit 0 ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Now get the command
    command="${1:-up}"

    case "${command}" in
        up)
            run_up
            ;;
        host)
            run_host
            ;;
        app)
            run_app
            ;;
        reset)
            reset
            ;;
        pause)
            pause
            ;;
        resume)
            resume
            ;;
        teardown)
            teardown
            ;;
        *)
            error "Unknown command '${command}'. Use one of: up, host, app, reset, pause, resume, teardown"
            exit 1
            ;;
    esac
}

main "$@"
