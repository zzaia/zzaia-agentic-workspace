# ZZAIA Agentic Workspace — Ubuntu Container
# All tools provisioned via mise.toml. SSH + vscode-server (code serve-web) accessible.
# WORKSPACE_NAME is runtime-only — one image serves all workspace deployments.
FROM ubuntu:24.04

ARG TECTONIC_VER=""
ARG VSCODE_COMMIT=""

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
    curl git openssh-server tmux plantuml sudo pipx \
    ca-certificates build-essential locales gpg gpg-agent \
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

# ── External binaries: tectonic + VS Code CLI + VS Code server ────────────────
# Pin TECTONIC_VER and VSCODE_COMMIT as build ARGs for reproducible builds.
# Leave empty to resolve latest at build time (non-reproducible).
RUN _TECTONIC_VER="${TECTONIC_VER:-$(curl -fsSL https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest \
        | grep '"tag_name"' | sed 's/.*"tectonic@//;s/".*//') }" \
    && _TECTONIC_VER=$(printf '%s' "$_TECTONIC_VER" | tr -d ' \n') \
    && curl -fsSL "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic@${_TECTONIC_VER}/tectonic-${_TECTONIC_VER}-x86_64-unknown-linux-musl.tar.gz" \
        | tar xz -C /usr/local/bin \
    && curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" | tar xz -C /usr/local/bin \
    && _VSCODE_COMMIT="${VSCODE_COMMIT:-$(curl -fsSL 'https://update.code.visualstudio.com/api/update/linux-x64/stable/latest' \
        | grep -o '"version":"[^"]*"' | cut -d'"' -f4)}" \
    && echo "$_VSCODE_COMMIT" > /tmp/vscode-commit \
    && mkdir -p /tmp/vscode-server-seed \
    && curl -fsSL "https://update.code.visualstudio.com/commit:${_VSCODE_COMMIT}/server-linux-x64/stable" \
        | tar xz -C /tmp/vscode-server-seed --strip-components 1

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

# ── Non-root user (fixed: "user") + VS Code server placed in home ─────────────
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user \
    && mkdir -p /home/user/.ssh \
               /home/user/workspace/host /home/user/.local/share/vscode-server \
    && chmod 700 /home/user/.ssh \
    && VSCODE_COMMIT=$(cat /tmp/vscode-commit) \
    && mkdir -p /home/user/.vscode/cli/servers/Stable-${VSCODE_COMMIT}/server \
    && mv /tmp/vscode-server-seed/* /home/user/.vscode/cli/servers/Stable-${VSCODE_COMMIT}/server/ \
    && rm -rf /tmp/vscode-server-seed /tmp/vscode-commit \
    && chown -R user:user /home/user

USER user
WORKDIR /home/user

RUN echo 'eval "$(mise activate bash)"' >> /home/user/.bashrc

ENV PATH="/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:$PATH"

# ── Miniforge3 (conda) — no config dependency, cache-stable ──────────────────
RUN curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
        -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /home/user/miniforge3 \
    && rm /tmp/miniforge.sh \
    && /home/user/miniforge3/bin/conda init bash

# ── Tools + VS Code extensions via mise.toml ──────────────────────────────────
COPY --chown=user:user docker/mise.toml /home/user/mise.toml
RUN mise trust /home/user/mise.toml \
    && mise install \
    && mise run python-packages \
    && mise run conda-envs \
    && mise run dotnet-tools \
    && mise run rtk \
    && mise run claude-plugins \
    && mise run gh-extensions \
    && mise run vscode-extensions

# ── Workspace configuration — after expensive layers for better cache ─────────
COPY --chown=user:user workspace/ /home/user/workspace/

# ── Agent configs — flat merge into HOME ──────────────────────────────────────
COPY --chown=user:user agents/gemini/  /home/user/
COPY --chown=user:user agents/codex/   /home/user/
COPY --chown=user:user agents/copilot/ /home/user/

# ── VS Code server config — last so it wins over agent defaults ───────────────
# {{WORKSPACE_NAME}} templating and .code-workspace rename are deferred to entrypoint
# so the same image works for any WORKSPACE_NAME at runtime.
COPY --chown=user:user vscode/ /home/user/

# ── Dev Containers support ────────────────────────────────────────────────────
RUN mkdir -p /home/user/.devcontainer
COPY --chown=user:user docker/devcontainer.json /home/user/.devcontainer/devcontainer.json

# ── Entrypoint ────────────────────────────────────────────────────────────────
USER root
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${SSH_PORT}

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=5 \
    CMD bash -c "</dev/tcp/localhost/$(cat /etc/ssh-port)"

ENTRYPOINT ["/entrypoint.sh"]
