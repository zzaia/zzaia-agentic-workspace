FROM node:24.16.0-alpine3.23

RUN apk add --no-cache bash jq && npm install -g supergateway@3.4.3 mcp-remote@0.1.38 @opentelemetry/auto-instrumentations-node@0.76.0

COPY docker/containers/mcp-github/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
