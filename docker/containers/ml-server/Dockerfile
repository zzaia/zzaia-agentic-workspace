ARG GPU_ENABLED=false

FROM ubuntu:24.04 AS base-false
FROM nvidia/cuda:12.9.2-runtime-ubuntu24.04 AS base-true

FROM base-${GPU_ENABLED} AS final

RUN apt-get update && apt-get install -y \
    curl bzip2 ca-certificates python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1001 -s /bin/bash headroom \
    && mkdir -p /opt/ml-tools/.bootstrap /workspace \
    && chown -R headroom:headroom /opt/ml-tools /workspace

RUN pip3 install ansible-core --break-system-packages

ENV INSTALL_PREFIX=/opt/ml-tools

COPY docker/containers/ml-server/entrypoint.sh /entrypoint.sh
COPY docker/containers/ml-server/scripts/versions.env /opt/scripts/versions.env
RUN chmod +x /entrypoint.sh

COPY docker/containers/ml-server/ansible /usr/local/lib/zzaia/ansible
RUN find /usr/local/lib/zzaia/ansible -name '*.yml' -exec chmod 644 {} + \
    && find /usr/local/lib/zzaia/ansible -name '*.ini' -exec chmod 644 {} + \
    && find /usr/local/lib/zzaia/ansible -name '*.cfg' -exec chmod 644 {} +

WORKDIR /opt/ml-tools
USER headroom

EXPOSE 8787

HEALTHCHECK --interval=15s --timeout=5s --retries=5 --start-period=15m \
    CMD curl -sf http://localhost:8787/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--memory", "--code-aware", "--no-telemetry"]
