# ZZAIA Workspace Base — Ubuntu Foundation Image
# Provides system packages, build-time tools, and workspace seed structure.
# Used as base for ssh-server, vscode-server, and containers-dev-server.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="ZZAIA Workspace Base"
LABEL org.opencontainers.image.description="Ubuntu-based workspace foundation with provisioning scripts"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    BROWSER=/usr/local/bin/browser-print

# ── System setup and build-time tools ─────────────────────────────────────────
COPY docker/containers/workspace-base/scripts /docker-scripts
RUN bash /docker-scripts/build-install.sh && rm -rf /docker-scripts

# ── Browser-print: prints OAuth URLs to terminal for headless auth ────────────
RUN printf '#!/bin/sh\necho ""\necho "Open this URL in your browser:"\necho "  $1"\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# ── Non-root user (fixed: "user") ────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user \
    && mkdir -p /opt/zzaia/home-seed \
    && chown -R user:user /opt/zzaia

USER user
WORKDIR /home/user

# ── Home seed — all home content staged outside the volume ───────────────────
# entrypoint.sh merges /opt/zzaia/home-seed/ into /home/user/ at runtime.
COPY --chown=user:user agents/gemini/                  /opt/zzaia/home-seed/
COPY --chown=user:user agents/codex/                   /opt/zzaia/home-seed/
COPY --chown=user:user agents/copilot/                 /opt/zzaia/home-seed/
COPY --chown=user:user agents/claude/.claude.json      /opt/zzaia/home-seed/.claude.json
# {{WORKSPACE_NAME}} templating and .code-workspace rename are deferred to entrypoint
COPY --chown=user:user vscode/                         /opt/zzaia/home-seed/
COPY --chown=user:user workspace/                      /opt/zzaia/home-seed/workspace/

# ── Bootstrap scripts available for child images ───────────────────────────────
USER root
COPY docker/containers/workspace-base/scripts /usr/local/lib/zzaia/scripts
RUN find /usr/local/lib/zzaia/scripts -name '*.sh' -exec chmod +x {} +
