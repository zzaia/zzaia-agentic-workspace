FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libicu74 \
    && rm -rf /var/lib/apt/lists/*

# Match workspace-server user uid
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user

COPY docker/containers/containers-dev-server/devcontainer.json /opt/zzaia/devcontainer.json
COPY docker/containers/containers-dev-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30m \
    CMD [ -f /opt/tools/.bootstrap/tools.ready ]

ENTRYPOINT ["/entrypoint.sh"]
