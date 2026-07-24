FROM node:24.16.0-alpine3.23

RUN apk add --no-cache bash python3 py3-pip && \
    pip install --break-system-packages uv

COPY docker/containers/mcp-aws-api/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
