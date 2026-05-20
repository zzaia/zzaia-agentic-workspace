FROM ubuntu:24.04

ARG VSCODE_PORT=8080

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    BROWSER=/usr/local/bin/browser-print \
    PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH \
    NVM_DIR=/opt/tools/.nvm \
    DOTNET_ROOT=/opt/tools/.dotnet

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        util-linux \
        libicu74 \
    && rm -rf /var/lib/apt/lists/*

RUN printf '#!/bin/sh\necho ""\necho "Open this URL in your browser:"\necho "  $1"\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# Match workspace-server user uid
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user

COPY docker/containers/vscode-server/entrypoint.sh /entrypoint.sh
COPY docker/containers/vscode-server/vscode-extensions.txt /usr/local/bin/vscode-extensions.txt
RUN chmod +x /entrypoint.sh

EXPOSE ${VSCODE_PORT}

HEALTHCHECK --interval=15s --timeout=5s --retries=5 --start-period=30m \
    CMD curl -sf http://localhost:${VSCODE_PORT:-8080}/ >/dev/null

ENTRYPOINT ["/entrypoint.sh"]
