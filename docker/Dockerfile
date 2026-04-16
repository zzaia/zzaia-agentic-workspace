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

# ── System packages + mise apt repo ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git openssh-server tmux plantuml tectonic docker.io \
    ca-certificates build-essential locales gpg gpg-agent \
    && locale-gen en_US.UTF-8 \
    && curl -fsSL https://mise.jdx.dev/gpg-key.pub \
        | gpg --dearmor -o /usr/share/keyrings/mise-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/mise-archive-keyring.gpg arch=amd64] \
        https://mise.jdx.dev/deb/stable/main /" > /etc/apt/sources.list.d/mise.list \
    && apt-get update && apt-get install -y --no-install-recommends mise \
    && rm -rf /var/lib/apt/lists/*

# ── Browser-print: prints OAuth URLs to terminal for headless auth ────────────
RUN printf '#!/bin/sh\necho "Open this URL in your browser: $1"\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

# ── SSH server ────────────────────────────────────────────────────────────────
COPY docker/sshd_config /etc/ssh/sshd_config.d/zzaia.conf

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash -u 1000 zzaia \
    && mkdir -p /home/zzaia/.ssh \
    && chmod 700 /home/zzaia/.ssh \
    && chown -R zzaia:zzaia /home/zzaia

USER zzaia
WORKDIR /home/zzaia

RUN echo 'eval "$(mise activate bash)"' >> /home/zzaia/.bashrc

ENV PATH="/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:$PATH" \
    EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","itemUrl":"https://marketplace.visualstudio.com/items","resourceUrlTemplate":"https://{publisher}.vscode-cdn.net/extensions/{publisher}/{name}/{version}/Microsoft.VisualStudio.Code.WebResources/{path}"}'

# ── Workspace configuration ───────────────────────────────────────────────────
COPY --chown=zzaia:zzaia mise.toml /home/zzaia/mise.toml
COPY --chown=zzaia:zzaia .claude/ /home/zzaia/.claude/
COPY --chown=zzaia:zzaia .vscode/ /home/zzaia/.vscode/
COPY --chown=zzaia:zzaia CLAUDE.md .mcp.json .claudeignore .gitignore \
    README.md QUICKSTART.md LICENSE zzaia-main.code-workspace /home/zzaia/

# ── Tools + tasks via mise.toml ──────────────────────────────────────────────
RUN mise install \
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
    ; do code-server --install-extension "$ext" || true; done


# ── Entrypoint ────────────────────────────────────────────────────────────────
USER root
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
