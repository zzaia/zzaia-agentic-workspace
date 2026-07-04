FROM zepai/knowledge-graph-mcp:standalone

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY docker/containers/mcp-graphiti/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
