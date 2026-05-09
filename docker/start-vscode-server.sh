#!/usr/bin/env bash
set -euo pipefail

export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:$PATH
export BROWSER=/usr/local/bin/browser-print
export HOME=/home/user

USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER")

# Create VS Code server dirs as user — root lacks DAC_OVERRIDE to write into
# user-owned home. chown -R afterwards normalizes any root-created remnants.
"${USER_RUN[@]}" mkdir -p /home/user/.vscode-server/data /home/user/.vscode-server/extensions
chown -R user:user /home/user/.vscode-server 2>/dev/null || true

"${USER_RUN[@]}" code serve-web \
  --host 0.0.0.0 \
  --port "${VSCODE_PORT:-8080}" \
  --without-connection-token \
  --accept-server-license-terms \
  --server-data-dir /home/user/.vscode-server \
  --default-workspace "/home/user/${WORKSPACE_NAME:-zzaia}.code-workspace" &
SERVER_PID=$!

EXT_DIR=/home/user/.vscode-server/extensions
EXT_SENTINEL=/home/user/.vscode-server/.extensions-installed
"${USER_RUN[@]}" mkdir -p "$EXT_DIR"
chown user:user "$EXT_DIR" 2>/dev/null || true
chmod 0775 "$EXT_DIR" || true

VSCODE_CLI=""
CLI_DISCOVERY_MAX_ATTEMPTS="${CLI_DISCOVERY_MAX_ATTEMPTS:-120}"
CLI_DISCOVERY_DELAY_SECONDS="${CLI_DISCOVERY_DELAY_SECONDS:-3}"
for _ in $(seq 1 "$CLI_DISCOVERY_MAX_ATTEMPTS"); do
  VSCODE_CLI=$(
    find /home/user/.vscode/cli/serve-web \
      -name code-server -type f 2>/dev/null | head -1 || true
  )
  [ -n "$VSCODE_CLI" ] && break
  sleep "$CLI_DISCOVERY_DELAY_SECONDS"
done

if [ -z "$VSCODE_CLI" ]; then
  echo "WARN: code-server CLI not found; skipping extension bootstrap." >&2
  wait "$SERVER_PID"
  exit 0
fi

_CLI_VER=$("$VSCODE_CLI" --version 2>/dev/null | head -1 || echo "unknown")
if [ ! -f "$EXT_SENTINEL" ] || [ "$(cat "$EXT_SENTINEL" 2>/dev/null)" != "$_CLI_VER" ]; then
  _install_ext() {
    local ext="$1" attempt=1 max=5 delay=10 out rc
    while [ "$attempt" -le "$max" ]; do
      # Under set -e, a failing command substitution in assignment can terminate
      # the script. Capture stdout/stderr and exit code explicitly.
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

  echo "$_CLI_VER" > "$EXT_SENTINEL" || true
fi

wait "$SERVER_PID"
