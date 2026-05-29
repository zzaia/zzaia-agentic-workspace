FROM hashicorp/vault:latest

LABEL org.opencontainers.image.title="ZZAIA Vault with Secret Sync"
LABEL org.opencontainers.image.description="HashiCorp Vault with automatic environment variable secret sync"

# vault image (Alpine) ships with wget but not curl or jq — install jq and bash
USER root
RUN apk add --no-cache bash jq

# Copy Vault configuration and entrypoint with correct permissions
COPY docker/containers/vault-server/vault.hcl /vault/config/vault.hcl
COPY docker/containers/vault-server/common.sh /vault/common.sh
COPY docker/containers/vault-server/entrypoint.sh /vault/entrypoint.sh
COPY docker/containers/vault-server/policies /vault/policies
RUN chmod +x /vault/entrypoint.sh /vault/common.sh && \
    chmod 644 /vault/config/vault.hcl && \
    find /vault/policies -type f -exec chmod 644 {} + && \
    mkdir -p /vault/data && \
    chown -R vault:vault /vault/config /vault/policies /vault/entrypoint.sh /vault/common.sh /vault/data
USER vault

ENTRYPOINT ["/vault/entrypoint.sh"]
CMD [""]
