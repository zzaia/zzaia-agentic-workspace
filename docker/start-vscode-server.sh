#!/usr/bin/env bash
set -euo pipefail

export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:$PATH
export BROWSER=/usr/local/bin/browser-print

code serve-web \
  --host 0.0.0.0 \
  --port "${VSCODE_PORT:-8080}" \
  --without-connection-token \
  --accept-server-license-terms \
  --server-data-dir /home/user/.vscode-server \
  --default-workspace "/home/user/${WORKSPACE_NAME:-zzaia}.code-workspace" &
SERVER_PID=$!

EXT_DIR=/home/user/.vscode-server/extensions
EXT_SENTINEL=/home/user/.vscode-server/.extensions-installed
mkdir -p "$EXT_DIR"
chmod 0775 "$EXT_DIR" || true

VSCODE_CLI=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  VSCODE_CLI=$(find /root/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | head -1)
  [ -n "$VSCODE_CLI" ] && break
  sleep 3
done

if [ -z "$VSCODE_CLI" ]; then
  echo "WARN: code-server CLI not found; skipping extension bootstrap." >&2
  wait "$SERVER_PID"
  exit 0
fi

_CLI_VER=$("$VSCODE_CLI" --version 2>/dev/null | head -1 || echo "unknown")
if [ ! -f "$EXT_SENTINEL" ] || [ "$(cat "$EXT_SENTINEL" 2>/dev/null)" != "$_CLI_VER" ]; then
  _install_ext() {
    local ext="$1" attempt=1 max=5 delay=10 out
    while [ "$attempt" -le "$max" ]; do
      out=$("$VSCODE_CLI" --extensions-dir "$EXT_DIR" --install-extension "$ext" --target linux-x64 2>&1)
      if echo "$out" | grep -qiE "successfully installed|already installed"; then
        echo "$out" | grep -v "already installed" || true
        return 0
      fi
      echo "WARN: $ext attempt $attempt/$max failed; retrying in ${delay}s..." >&2
      sleep "$delay"
      attempt=$((attempt + 1))
      delay=$((delay * 2))
    done
    echo "WARN: $ext could not be installed after $max attempts; continuing." >&2
  }

  for ext in \
    teabyii.ayu coderholiclt.night-owl miguelsolorio.fluent-icons \
    pkief.material-product-icons vscode-icons-team.vscode-icons \
    anthropic.claude-code \
    alefragnani.project-manager codeinklingon.git-worktree-menu \
    eamodio.gitlens editorconfig.editorconfig esbenp.prettier-vscode \
    fullstackspider.visual-nuget gaoshan0621.csharp-format-usings \
    github.copilot github.copilot-chat \
    google.geminicodeassist google.gemini-cli-vscode-ide-companion openai.chatgpt \
    gruntfuggly.todo-tree kreativ-software.csharpextensions \
    mermaidchart.vscode-mermaid-chart ms-azure-devops.azure-pipelines \
    ms-dotnettools.csdevkit ms-dotnettools.csharp ms-dotnettools.vscode-dotnet-runtime \
    ms-python.debugpy ms-python.python ms-python.vscode-pylance \
    ms-python.vscode-python-envs ms-toolsai.jupyter ms-toolsai.jupyter-keymap \
    ms-toolsai.jupyter-renderers ms-toolsai.vscode-jupyter-cell-tags \
    ms-toolsai.vscode-jupyter-slideshow orsenkucher.vscode-graphql \
    redhat.vscode-xml redhat.vscode-yaml streetsidesoftware.code-spell-checker \
    tamasfe.even-better-toml ms-vscode.vscode-websearchforcopilot \
    tomblind.scm-buttons-vscode vscodevim.vim; do
    _install_ext "$ext"
  done

  echo "$_CLI_VER" > "$EXT_SENTINEL" || true
fi

wait "$SERVER_PID"
