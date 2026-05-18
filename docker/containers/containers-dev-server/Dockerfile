FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/home/user/.local/bin:/home/user/.npm-global/bin:/home/user/.dotnet:/home/user/.dotnet/tools:/home/user/miniforge3/bin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Match workspace-server user uid
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user

COPY docker/containers/containers-dev-server/devcontainer.json /opt/zzaia/devcontainer.json
COPY docker/containers/containers-dev-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
