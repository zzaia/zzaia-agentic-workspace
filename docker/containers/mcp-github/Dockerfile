FROM node:lts-alpine

RUN apk add --no-cache bash jq && npm install -g supergateway@3.4.3

COPY docker/containers/mcp-github/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
