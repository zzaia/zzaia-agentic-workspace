FROM node:lts-alpine

COPY docker/containers/mcp-azure-devops/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
