FROM node:lts-alpine

COPY docker/containers/mcp-postman/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
