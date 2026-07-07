FROM zepai/knowledge-graph-mcp:standalone

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY docker/containers/mcp-graphiti/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create non-root user and ensure necessary directories are writable
RUN groupadd -r graphiti && useradd -r -g graphiti graphiti && \
    mkdir -p /app/mcp/config && \
    chown -R graphiti:graphiti /app/mcp

USER graphiti

ENTRYPOINT ["/entrypoint.sh"]
