FROM zzaia-workspace-base:latest

ARG VSCODE_PORT=8080

COPY docker/containers/vscode-server/entrypoint.sh /entrypoint.sh
COPY docker/containers/vscode-server/vscode-extensions.txt /usr/local/bin/vscode-extensions.txt
RUN chmod +x /entrypoint.sh

EXPOSE ${VSCODE_PORT}

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=10 \
    CMD curl -sf http://localhost:8080/ >/dev/null && [ -f /home/user/.vscode-server/.extensions-installed ]

ENTRYPOINT ["/entrypoint.sh"]
