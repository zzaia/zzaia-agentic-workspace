FROM node:24.16.0-alpine3.23

RUN apk add --no-cache bash jq python3 py3-pip && \
    pip install --break-system-packages uv && \
    npm install -g supergateway@3.4.3

COPY docker/containers/mcp-aws-postgres/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
