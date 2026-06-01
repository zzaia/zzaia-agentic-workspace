FROM hashicorp/vault:latest

LABEL org.opencontainers.image.title="ZZAIA Vault Production"
LABEL org.opencontainers.image.description="HashiCorp Vault production mode with Bitwarden secret bootstrap"

USER root
RUN apk add --no-cache bash jq curl openssh-keygen ansible-core

COPY docker/containers/vault-server/vault.hcl /vault/config/vault.hcl
COPY docker/containers/vault-server/common.sh /vault/common.sh
COPY docker/containers/vault-server/entrypoint.sh /vault/entrypoint.sh
COPY docker/containers/vault-server/policies /vault/policies
COPY docker/containers/vault-server/ansible /vault/ansible
RUN chmod +x /vault/entrypoint.sh /vault/common.sh && \
    chmod 644 /vault/config/vault.hcl && \
    find /vault/policies -type f -exec chmod 644 {} + && \
    find /vault/ansible -name '*.yml' -exec chmod 644 {} + && \
    find /vault/ansible -name '*.ini' -exec chmod 644 {} + && \
    find /vault/ansible -name '*.cfg' -exec chmod 644 {} + && \
    mkdir -p /vault/data && \
    chmod 755 /vault/data && \
    chown -R vault:vault /vault/config /vault/policies /vault/common.sh /vault/ansible /vault/data
# USER vault — runs as root so vault can write AppRole creds to /secrets shared volume

ENTRYPOINT ["/vault/entrypoint.sh"]
CMD [""]
