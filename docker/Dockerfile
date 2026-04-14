# ZZAIA Agentic Workspace — Ubuntu Container
# All tools provisioned via mise.toml. SSH-accessible, isolated from host.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="ZZAIA Agentic Workspace"
LABEL org.opencontainers.image.description="Ubuntu-based agentic development environment with SSH access"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git openssh-server tmux plantuml \
    ca-certificates build-essential locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ── SSH server ────────────────────────────────────────────────────────────────
RUN mkdir -p /var/run/sshd
COPY docker/sshd_config /etc/ssh/sshd_config.d/zzaia.conf

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash -u 1000 zzaia \
    && mkdir -p /home/zzaia/.ssh \
    && chmod 700 /home/zzaia/.ssh \
    && chown -R zzaia:zzaia /home/zzaia

USER zzaia
WORKDIR /home/zzaia

# ── mise ──────────────────────────────────────────────────────────────────────
RUN MISE_TMP=$(mktemp) \
    && curl -fsSL https://mise.run -o "$MISE_TMP" \
    && chmod +x "$MISE_TMP" \
    && "$MISE_TMP" \
    && rm -f "$MISE_TMP" \
    && echo 'eval "$(mise activate bash)"' >> /home/zzaia/.bashrc

# Include mise shims in PATH for subsequent RUN steps
ENV PATH="/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:$PATH"

# ── Tools via mise.toml ───────────────────────────────────────────────────────
# Installs: node, python, dotnet, k6, d2, dapr, miniforge3, claude-code, code-server
COPY --chown=zzaia:zzaia mise.toml /home/zzaia/mise.toml

RUN mise install

# ── mise tasks ────────────────────────────────────────────────────────────────
# python-packages: pypdf, python-docx, textual, jinja2, graphviz, diagrams
RUN mise run python-packages

# conda-envs: venv-analytics, venv-development (python 3.12)
RUN mise run conda-envs

# dotnet-tools: aspire workload, aspire global tool, aspirate
# Note: if dotnet tool install -g aspire fails (not on NuGet), the build
# continues — aspirate is the critical tool here.
RUN mise run dotnet-tools || true

# ── Entrypoint ────────────────────────────────────────────────────────────────
USER root
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
