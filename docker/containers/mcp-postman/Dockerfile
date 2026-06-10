FROM node:24.16.0-alpine3.23

RUN apk add --no-cache bash jq && npm install -g supergateway@3.4.3 @opentelemetry/auto-instrumentations-node@0.76.0 && npm install -g --ignore-scripts @postman/postman-mcp-server@2.9.0

COPY docker/containers/mcp-postman/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
