FROM node:lts-alpine

COPY docker/containers/mcp-tavily/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
