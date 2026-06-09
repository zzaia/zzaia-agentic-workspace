FROM node:lts-alpine

RUN apk add --no-cache bash jq && npm install -g supergateway@3.4.3 signoz-mcp-server@latest

COPY docker/containers/mcp-signoz/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
