FROM signoz/signoz:latest

LABEL org.opencontainers.image.title="ZZAIA SigNoz Server"
LABEL org.opencontainers.image.description="SigNoz with automatic admin provisioning and MCP token generation"

USER root
RUN apk add --no-cache curl jq

COPY docker/containers/signoz-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
