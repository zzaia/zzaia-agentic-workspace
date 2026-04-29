# ZZAIA Agentic Workspace — Ubuntu Container
# All tools provisioned via mise.toml. SSH + vscode-server (code serve-web) accessible.
FROM ubuntu:24.04

ARG WORKSPACE_NAME=zzaia

LABEL org.opencontainers.image.title="ZZAIA Agentic Workspace"
LABEL org.opencontainers.image.description="Ubuntu-based agentic development environment with SSH and browser VS Code access"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    BROWSER=/usr/local/bin/browser-print \
    WORKSPACE_NAME=${WORKSPACE_NAME}

# ── System packages + Docker CE CLI (no daemon) + mise ───────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git openssh-server tmux plantuml sudo pipx \
    ca-certificates build-essential locales gpg gpg-agent \
    && locale-gen en_US.UTF-8 \
    && TECTONIC_VER=$(curl -fsSL https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest \
        | grep '"tag_name"' | sed 's/.*"tectonic@//;s/".*//') \
    && curl -fsSL "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic@${TECTONIC_VER}/tectonic-${TECTONIC_VER}-x86_64-unknown-linux-musl.tar.gz" \
        | tar xz -C /usr/local/bin \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu noble stable" \
        > /etc/apt/sources.list.d/docker.list \
    && curl -fsSL https://mise.jdx.dev/gpg-key.pub \
        | gpg --dearmor -o /usr/share/keyrings/mise-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
        > /etc/apt/sources.list.d/mise.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli mise \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" | tar xz -C /usr/local/bin

# ── Browser-print: prints OAuth URLs to terminal for headless auth ────────────
RUN printf '#!/bin/sh\necho ""\necho "Open this URL in your browser:"\necho "  $1"\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# ── SSH server ────────────────────────────────────────────────────────────────
ARG SSH_PORT=2222
ARG VSCODE_PORT=8080
COPY docker/sshd_config /etc/ssh/sshd_config.d/${WORKSPACE_NAME}.conf
RUN sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config.d/${WORKSPACE_NAME}.conf \
    && grep -q 'Include.*sshd_config.d' /etc/ssh/sshd_config \
    || echo 'Include /etc/ssh/sshd_config.d/*.conf' >> /etc/ssh/sshd_config

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 ${WORKSPACE_NAME} \
    && mkdir -p /home/${WORKSPACE_NAME}/.ssh \
               /home/${WORKSPACE_NAME}/workspace/host /home/${WORKSPACE_NAME}/.local/share/vscode-server \
    && chmod 700 /home/${WORKSPACE_NAME}/.ssh \
    && chown -R ${WORKSPACE_NAME}:${WORKSPACE_NAME} /home/${WORKSPACE_NAME}

USER ${WORKSPACE_NAME}
WORKDIR /home/${WORKSPACE_NAME}

RUN echo 'eval "$(mise activate bash)"' >> /home/${WORKSPACE_NAME}/.bashrc

ENV PATH="/home/${WORKSPACE_NAME}/miniforge3/bin:/home/${WORKSPACE_NAME}/.local/share/mise/shims:/home/${WORKSPACE_NAME}/.local/bin:/home/${WORKSPACE_NAME}/.dotnet/tools:$PATH"

# ── Miniforge3 (conda) — no config dependency, cache-stable ──────────────────
RUN curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
        -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /home/${WORKSPACE_NAME}/miniforge3 \
    && rm /tmp/miniforge.sh \
    && /home/${WORKSPACE_NAME}/miniforge3/bin/conda init bash

# ── Tools via mise.toml — COPY immediately before use to isolate cache misses ─
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} docker/mise.toml /home/${WORKSPACE_NAME}/mise.toml
RUN mise trust /home/${WORKSPACE_NAME}/mise.toml \
    && mise install \
    && mise run python-packages \
    && mise run conda-envs \
    && mise run dotnet-tools

# ── VS Code extensions — pre-install during build ────────────────────────────
RUN code serve-web \
        --host 127.0.0.1 \
        --port ${VSCODE_PORT} \
        --without-connection-token \
        --accept-server-license-terms \
        --server-data-dir /home/${WORKSPACE_NAME}/.vscode-server \
        > /tmp/vscode-build.log 2>&1 & \
    SERVER_PID=$! && \
    until curl -sf http://127.0.0.1:${VSCODE_PORT} > /dev/null 2>&1; do sleep 2; done && \
    VSCODE_CLI=$(find /home/${WORKSPACE_NAME}/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | head -1) && \
    [ -n "$VSCODE_CLI" ] || { echo "ERROR: code-server binary not found in .vscode/cli/serve-web" >&2; kill $SERVER_PID 2>/dev/null; exit 1; } && \
    EXT_DIR="/home/${WORKSPACE_NAME}/.vscode-server/extensions" && \
    for ext in \
        teabyii.ayu \
        coderholiclt.night-owl \
        anthropic.claude-code \
        alefragnani.project-manager \
        codeinklingon.git-worktree-menu \
        eamodio.gitlens \
        editorconfig.editorconfig \
        esbenp.prettier-vscode \
        fullstackspider.visual-nuget \
        gaoshan0621.csharp-format-usings \
        github.copilot \
        github.copilot-chat \
        google.gemini-code-assist \
        gruntfuggly.todo-tree \
        kreativ-software.csharpextensions \
        mermaidchart.vscode-mermaid-chart \
        ms-azure-devops.azure-pipelines \
        ms-dotnettools.csharp \
        ms-dotnettools.vscode-dotnet-runtime \
        ms-python.debugpy \
        ms-python.python \
        ms-python.vscode-pylance \
        ms-python.vscode-python-envs \
        ms-toolsai.jupyter \
        ms-toolsai.jupyter-keymap \
        ms-toolsai.jupyter-renderers \
        ms-toolsai.vscode-jupyter-cell-tags \
        ms-toolsai.vscode-jupyter-slideshow \
        ms-vsliveshare.vsliveshare \
        ms-vsliveshare.vsliveshare-audio \
        orsenkucher.vscode-graphql \
        redhat.vscode-xml \
        redhat.vscode-yaml \
        streetsidesoftware.code-spell-checker \
        tomblind.scm-buttons-vscode \
        vscodevim.vim \
    ; do \
        "$VSCODE_CLI" --extensions-dir "$EXT_DIR" --install-extension "$ext" 2>&1 \
            | grep -v "already installed" || true; \
    done && \
    kill $SERVER_PID 2>/dev/null || true

# ── Workspace configuration — after expensive layers for better cache ─────────
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} README.md QUICKSTART.md ARCHITECTURE.md \
    LICENSE WELCOME.md /home/${WORKSPACE_NAME}/
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} workspace/ /home/${WORKSPACE_NAME}/workspace/

# ── VS Code server config — profile, settings, workspace tasks/launch ─────────
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} vscode/ /home/${WORKSPACE_NAME}/
RUN find "/home/${WORKSPACE_NAME}/.vscode-server" "/home/${WORKSPACE_NAME}/workspace" \
        -name "*.json" -o -name "*.code-workspace" | \
        xargs sed -i "s/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/g" && \
    mv "/home/${WORKSPACE_NAME}/workspace/zzaia.code-workspace" \
       "/home/${WORKSPACE_NAME}/workspace/${WORKSPACE_NAME}.code-workspace" 2>/dev/null || true

# ── Agent configs — only claude agent configs flat merge into HOME ─
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} agents/claude/  /home/${WORKSPACE_NAME}/
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} agents/gemini/  /home/${WORKSPACE_NAME}/
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} agents/codex/   /home/${WORKSPACE_NAME}/
COPY --chown=${WORKSPACE_NAME}:${WORKSPACE_NAME} agents/copilot/ /home/${WORKSPACE_NAME}/

# ── Entrypoint ────────────────────────────────────────────────────────────────
USER root
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${SSH_PORT}
EXPOSE ${VSCODE_PORT}
ENTRYPOINT ["/entrypoint.sh"]
