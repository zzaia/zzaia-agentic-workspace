FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV INSTALL_PREFIX=/opt/tools

COPY docker/containers/proxy-headroom/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

HEALTHCHECK --interval=15s --timeout=5s --retries=5 --start-period=5m \
    CMD curl -sf http://localhost:8787/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--memory", "--code-graph", "--no-telemetry"]
