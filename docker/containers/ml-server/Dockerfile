FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl bzip2 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1001 -s /bin/bash headroom \
    && mkdir -p /opt/ml-tools/.bootstrap /workspace \
    && chown -R headroom:headroom /opt/ml-tools /workspace

ENV INSTALL_PREFIX=/opt/ml-tools

COPY docker/containers/ml-server/entrypoint.sh /entrypoint.sh
COPY docker/containers/ml-server/scripts/versions.env /opt/scripts/versions.env
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
USER headroom

HEALTHCHECK --interval=15s --timeout=5s --retries=5 --start-period=15m \
    CMD curl -sf http://localhost:8787/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--memory", "--code-aware", "--no-telemetry"]
