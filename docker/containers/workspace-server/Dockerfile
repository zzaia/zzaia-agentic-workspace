# ZZAIA Workspace Server — Ubuntu foundation with SSH, tools, shared home
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="ZZAIA Workspace Server"
LABEL org.opencontainers.image.description="All-in-one workspace: tools, SSH, shared home"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    BROWSER=/usr/local/bin/browser-print \
    PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH \
    NVM_DIR=/opt/tools/.nvm \
    DOTNET_ROOT=/opt/tools/.dotnet

# System packages + openssh-server
COPY docker/containers/workspace-server/scripts /docker-scripts
RUN bash /docker-scripts/build-install.sh && rm -rf /docker-scripts

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Browser-print: prints OAuth URLs to terminal for headless auth
RUN printf '#!/bin/sh\necho ""\necho "Open this URL in your browser:"\necho "  $1"\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# Non-root user (fixed: "user", uid 1000)
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user \
    && mkdir -p /opt/zzaia/home-seed \
    && chown -R user:user /opt/zzaia

USER user
WORKDIR /home/user

# Home seed — merged into /home/user at runtime by entrypoint
COPY --chown=user:user agents/gemini/                  /opt/zzaia/home-seed/
COPY --chown=user:user agents/codex/                   /opt/zzaia/home-seed/
COPY --chown=user:user agents/copilot/                 /opt/zzaia/home-seed/
COPY --chown=user:user agents/claude/.claude.json                  /opt/zzaia/home-seed/.claude.json
COPY --chown=user:user agents/claude/.mcp.json                     /opt/zzaia/home-seed/.mcp.json
COPY --chown=user:user agents/claude/.claude/settings.json         /opt/zzaia/home-seed/.claude/settings.json
COPY --chown=user:user agents/claude/.claude/settings.local.json   /opt/zzaia/home-seed/.claude/settings.local.json
COPY --chown=user:user vscode/                         /opt/zzaia/home-seed/
COPY --chown=user:user workspace/                      /opt/zzaia/home-seed/workspace/

USER root
COPY docker/containers/workspace-server/scripts /usr/local/lib/zzaia/scripts
RUN find /usr/local/lib/zzaia/scripts -name '*.sh' -exec chmod +x {} +

# SSH configuration
COPY docker/sshd_config /etc/ssh/sshd_config.d/workspace.conf
RUN grep -q 'Include.*sshd_config.d' /etc/ssh/sshd_config \
    || echo 'Include /etc/ssh/sshd_config.d/*.conf' >> /etc/ssh/sshd_config

COPY docker/containers/workspace-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/entrypoint.sh"]
