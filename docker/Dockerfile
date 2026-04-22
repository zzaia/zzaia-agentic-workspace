# ZZAIA Agentic Workspace — Ubuntu Container
# All tools provisioned via mise.toml. SSH + code-server accessible.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="ZZAIA Agentic Workspace"
LABEL org.opencontainers.image.description="Ubuntu-based agentic development environment with SSH and browser VS Code access"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    BROWSER=/usr/local/bin/browser-print

# ── System packages + Docker CE CLI (no daemon) + mise ───────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git openssh-server tmux plantuml sudo \
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
    && rm -rf /var/lib/apt/lists/*

# ── Browser-print: prints OAuth URLs to terminal for headless auth ────────────
RUN printf '#!/bin/sh\nurl="$1"\necho ""\necho "Open this URL in your browser:"\necho "  $url"\necho ""\necho "After authentication, the browser will redirect to localhost:43279."\necho "This port is forwarded from the container — ensure docker-compose port 43279 is mapped."\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# ── SSH server ────────────────────────────────────────────────────────────────
COPY docker/sshd_config /etc/ssh/sshd_config.d/zzaia.conf
RUN grep -q 'Include.*sshd_config.d' /etc/ssh/sshd_config \
    || echo 'Include /etc/ssh/sshd_config.d/*.conf' >> /etc/ssh/sshd_config

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 zzaia \
    && mkdir -p /home/zzaia/.ssh /home/zzaia/welcome /home/zzaia/workspace \
               /home/zzaia/.local/share/code-server \
    && chmod 700 /home/zzaia/.ssh \
    && chown -R zzaia:zzaia /home/zzaia

# ── code-server ───────────────────────────────────────────────────────────────
RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

USER zzaia
WORKDIR /home/zzaia

RUN echo 'eval "$(mise activate bash)"' >> /home/zzaia/.bashrc

ENV PATH="/home/zzaia/miniforge3/bin:/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:/home/zzaia/.dotnet/tools:$PATH" \
    EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","itemUrl":"https://marketplace.visualstudio.com/items","resourceUrlTemplate":"https://{publisher}.vscode-cdn.net/extensions/{publisher}/{name}/{version}/Microsoft.VisualStudio.Code.WebResources/{path}"}'

# ── Miniforge3 (conda) — no config dependency, cache-stable ──────────────────
RUN curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
        -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /home/zzaia/miniforge3 \
    && rm /tmp/miniforge.sh \
    && /home/zzaia/miniforge3/bin/conda init bash

# ── Tools via mise.toml — COPY immediately before use to isolate cache misses ─
COPY --chown=zzaia:zzaia mise.toml /home/zzaia/mise.toml
RUN mise trust ~/mise.toml \
    && mise install \
    && mise run python-packages \
    && mise run conda-envs \
    && mise run dotnet-tools

# ── VS Code extensions (Microsoft marketplace via EXTENSIONS_GALLERY) ─────────
RUN for ext in \
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
        gruntfuggly.todo-tree \
        kreativ-software.csharpextensions \
        mermaidchart.vscode-mermaid-chart \
        ms-azure-devops.azure-pipelines \
        ms-dotnettools.csdevkit \
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
        orsenkucher.vscode-graphql \
        redhat.vscode-xml \
        redhat.vscode-yaml \
        streetsidesoftware.code-spell-checker \
        tomblind.scm-buttons-vscode \
        vscodevim.vim \
    ; do code-server --install-extension "$ext" || echo "WARNING: failed to install extension: $ext" >&2; done

# ── Workspace configuration — after expensive layers for better cache ─────────
COPY --chown=zzaia:zzaia .claude/ /home/zzaia/.claude/
COPY --chown=zzaia:zzaia .vscode/ /home/zzaia/.vscode/
COPY --chown=zzaia:zzaia CLAUDE.md .claudeignore .gitignore \
    README.md QUICKSTART.md LICENSE zzaia-main.code-workspace /home/zzaia/
COPY --chown=zzaia:zzaia docker/.mcp.json /home/zzaia/.mcp.json
COPY --chown=zzaia:zzaia WELCOME.md /home/zzaia/README.md
COPY --chown=zzaia:zzaia .claude/workspace/host/ /home/zzaia/.claude/workspace/host/

RUN echo 'alias claude="claude --dangerously-skip-permissions"' >> /home/zzaia/.bashrc

# ── Entrypoint ────────────────────────────────────────────────────────────────
USER root
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
