#!/usr/bin/env bash
set -euo pipefail

export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:$PATH
export BROWSER=/usr/local/bin/browser-print
export HOME=/home/user

USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER")

# ── Credential fallback — inject OAuth token from credentials file if env var unset ─
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  _cred_file="/home/user/.claude/.credentials.json"
  if [ -f "$_cred_file" ]; then
    _token=$(grep -oP '"accessToken":"\K[^"]+' "$_cred_file" 2>/dev/null || true)
    if [ -n "$_token" ]; then
      export CLAUDE_CODE_OAUTH_TOKEN="$_token"
      USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER" CLAUDE_CODE_OAUTH_TOKEN="$_token")
    fi
  fi
fi

# Create VS Code server dirs as user — root lacks DAC_OVERRIDE to write into
# user-owned home. chown -R afterwards normalizes any root-created remnants.
"${USER_RUN[@]}" mkdir -p /home/user/.vscode-server/data /home/user/.vscode-server/extensions
chown -R user:user /home/user/.vscode-server 2>/dev/null || true

EXT_DIR=/home/user/.vscode-server/extensions
EXT_SENTINEL=/home/user/.vscode-server/.extensions-installed
"${USER_RUN[@]}" mkdir -p "$EXT_DIR"

# ── Discover or download VS Code inner binary ─────────────────────────────────
# Must use the inner binary directly on TCP — the code CLI proxy layer causes
# browser WebSocket timeouts. code serve-web is only used to trigger the download.
VSCODE_CLI=$(find /home/user/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | grep -v '\.staging' | head -1 || true)

if [ -z "$VSCODE_CLI" ]; then
  echo "VS Code inner binary not found — triggering download via code serve-web..."
  "${USER_RUN[@]}" code serve-web \
    --host 127.0.0.1 \
    --port 19999 \
    --without-connection-token \
    --accept-server-license-terms \
    --server-data-dir /home/user/.vscode-server &
  DOWNLOAD_PID=$!

  # Wait for port 19999 to open (up to 60s)
  for _ in $(seq 1 60); do
    if curl -s http://127.0.0.1:19999 -o /dev/null 2>/dev/null; then
      echo "Port 19999 ready — download triggered."
      break
    fi
    sleep 1
  done

  # Poll for the inner binary (download only starts after HTTP connection above)
  CLI_DISCOVERY_MAX="${CLI_DISCOVERY_MAX_ATTEMPTS:-600}"
  CLI_DISCOVERY_DELAY="${CLI_DISCOVERY_DELAY_SECONDS:-3}"
  for _ in $(seq 1 "$CLI_DISCOVERY_MAX"); do
    VSCODE_CLI=$(find /home/user/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | grep -v '\.staging' | head -1 || true)
    [ -n "$VSCODE_CLI" ] && break
    sleep "$CLI_DISCOVERY_DELAY"
  done

  kill "$DOWNLOAD_PID" 2>/dev/null || true
  wait "$DOWNLOAD_PID" 2>/dev/null || true
fi

if [ -z "$VSCODE_CLI" ]; then
  echo "ERROR: VS Code Server could not be downloaded." >&2
  exit 1
fi

# ── Start VS Code Server directly on TCP (bypasses CLI proxy WebSocket issues)
"${USER_RUN[@]}" "$VSCODE_CLI" \
  --host 0.0.0.0 \
  --port "${VSCODE_PORT:-8080}" \
  --without-connection-token \
  --accept-server-license-terms \
  --server-data-dir /home/user/.vscode-server \
  --default-workspace "/home/user/${WORKSPACE_NAME:-zzaia}.code-workspace" &
SERVER_PID=$!

# ── Extension bootstrap ───────────────────────────────────────────────────────
_CLI_VER=$("$VSCODE_CLI" --version 2>/dev/null | head -1 || echo "unknown")
if [ ! -f "$EXT_SENTINEL" ] || [ "$(cat "$EXT_SENTINEL" 2>/dev/null)" != "$_CLI_VER" ]; then
  _install_ext() {
    local ext="$1" attempt=1 max=5 delay=10 out rc
    while [ "$attempt" -le "$max" ]; do
      if out=$("${USER_RUN[@]}" "$VSCODE_CLI" --extensions-dir "$EXT_DIR" --install-extension "$ext" 2>&1); then
        rc=0
      else
        rc=$?
      fi
      if echo "$out" | grep -qiE "successfully installed|already installed"; then
        echo "$out" | grep -v "already installed" || true
        return 0
      fi
      echo "WARN: $ext attempt $attempt/$max failed (exit=${rc}); retrying in ${delay}s..." >&2
      sleep "$delay"
      attempt=$((attempt + 1))
      delay=$((delay * 2))
    done
    echo "WARN: $ext could not be installed after $max attempts; continuing." >&2
  }

  EXT_LIST_FILE="$(dirname "$0")/vscode-extensions.txt"
  while IFS= read -r ext || [ -n "$ext" ]; do
    [ -z "$ext" ] && continue
    _install_ext "$ext"
  done < "$EXT_LIST_FILE"

  "${USER_RUN[@]}" sh -c "echo '$_CLI_VER' > '$EXT_SENTINEL'" || true
fi

wait "$SERVER_PID"
