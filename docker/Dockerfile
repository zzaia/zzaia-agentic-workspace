# ZZAIA Agentic Workspace — Ubuntu Container
# All tools provisioned via mise.toml. SSH + vscode-server (code serve-web) accessible.
# WORKSPACE_NAME is runtime-only — one image serves all workspace deployments.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="ZZAIA Agentic Workspace"
LABEL org.opencontainers.image.description="Ubuntu-based agentic development environment with SSH and browser VS Code access"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    BROWSER=/usr/local/bin/browser-print

# ── System packages + Docker CE CLI + mise ────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl openssh-server sudo \
    ca-certificates locales gpg gpg-agent libicu74 \
    && locale-gen en_US.UTF-8 \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu noble stable" \
        > /etc/apt/sources.list.d/docker.list \
    && curl -fsSL https://mise.jdx.dev/gpg-key.pub \
        | gpg --dearmor -o /usr/share/keyrings/mise-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
        > /etc/apt/sources.list.d/mise.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli mise \
    && rm -rf /var/lib/apt/lists/*

# ── External binaries: VS Code CLI ────────────────────────────────────────────
# VS Code server is auto-downloaded by the CLI on first connection.
RUN curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" | tar xz -C /usr/local/bin

# ── Browser-print: prints OAuth URLs to terminal for headless auth ────────────
RUN printf '#!/bin/sh\necho ""\necho "Open this URL in your browser:"\necho "  $1"\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# ── SSH server ────────────────────────────────────────────────────────────────
ARG SSH_PORT=2222
ARG VSCODE_PORT=8080
COPY docker/sshd_config /etc/ssh/sshd_config.d/workspace.conf
RUN sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config.d/workspace.conf \
    && grep -q 'Include.*sshd_config.d' /etc/ssh/sshd_config \
    || echo 'Include /etc/ssh/sshd_config.d/*.conf' >> /etc/ssh/sshd_config \
    && echo "${SSH_PORT}" > /etc/ssh-port

# ── Non-root user (fixed: "user") ────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user \
    && mkdir -p /opt/zzaia/home-seed \
    && chown -R user:user /opt/zzaia

USER user
WORKDIR /home/user

# ── Home seed — all home content staged outside the volume ───────────────────
# entrypoint.sh merges /opt/zzaia/home-seed/ into /home/user/ at runtime.
COPY --chown=user:user docker/mise.toml                /opt/zzaia/home-seed/mise.toml
COPY --chown=user:user agents/gemini/                  /opt/zzaia/home-seed/
COPY --chown=user:user agents/codex/                   /opt/zzaia/home-seed/
COPY --chown=user:user agents/copilot/                 /opt/zzaia/home-seed/
# {{WORKSPACE_NAME}} templating and .code-workspace rename are deferred to entrypoint
COPY --chown=user:user vscode/                         /opt/zzaia/home-seed/
COPY --chown=user:user docker/devcontainer.json        /opt/zzaia/home-seed/.devcontainer/devcontainer.json
COPY --chown=user:user workspace/                      /opt/zzaia/home-seed/workspace/

# ── Entrypoint ────────────────────────────────────────────────────────────────
USER root
COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/scripts /usr/local/lib/zzaia/scripts
COPY docker/start-vscode-server.sh /usr/local/bin/start-vscode-server.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/start-vscode-server.sh \
    && chmod +x /usr/local/lib/zzaia/scripts/*.sh

EXPOSE ${SSH_PORT}

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=5 \
    CMD bash -c "</dev/tcp/localhost/$(cat /etc/ssh-port)"

ENTRYPOINT ["/entrypoint.sh"]
