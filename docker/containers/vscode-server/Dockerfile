FROM ubuntu:24.04

ARG VSCODE_PORT=8080

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    BROWSER=/usr/local/bin/browser-print \
    PATH=/home/user/.local/bin:/home/user/.npm-global/bin:/home/user/.dotnet:/home/user/.dotnet/tools:/home/user/miniforge3/bin:$PATH \
    NVM_DIR=/home/user/.nvm \
    DOTNET_ROOT=/home/user/.dotnet

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        util-linux \
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

ENTRYPOINT ["/entrypoint.sh"]
