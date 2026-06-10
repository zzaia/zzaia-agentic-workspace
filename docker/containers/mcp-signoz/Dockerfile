FROM node:24.16.0-alpine3.23

RUN apk add --no-cache bash jq && npm install -g supergateway@3.4.3 signoz-mcp-server@1.2.2 @opentelemetry/auto-instrumentations-node@0.76.0

COPY docker/containers/mcp-signoz/patch-signoz-mcp.js /patch-signoz-mcp.js
RUN node /patch-signoz-mcp.js

COPY docker/containers/mcp-signoz/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
