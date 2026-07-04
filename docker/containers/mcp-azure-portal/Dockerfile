FROM node:24.16.0-alpine3.23

RUN apk add --no-cache bash jq && npm install -g supergateway@3.4.3 @azure/mcp@latest

COPY docker/containers/mcp-azure-portal/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
