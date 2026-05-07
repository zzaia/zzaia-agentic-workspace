FROM node:lts-alpine

COPY docker/containers/mcp-github/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
