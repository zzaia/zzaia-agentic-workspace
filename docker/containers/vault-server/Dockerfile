FROM hashicorp/vault:latest

LABEL org.opencontainers.image.title="ZZAIA Vault Production"
LABEL org.opencontainers.image.description="HashiCorp Vault production mode with Bitwarden secret bootstrap"

USER root
RUN apk add --no-cache bash jq curl openssh-keygen && \
    curl -L https://github.com/bitwarden/sdk-sm/releases/latest/download/bws-x86_64-unknown-linux-musl.tar.gz | tar xz -C /usr/local/bin/ bws

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
