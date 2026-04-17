#!/bin/bash
# install-compose-mac.sh — delegates to install-compose.sh (macOS is auto-detected)
exec "$(dirname "${BASH_SOURCE[0]}")/install-compose.sh" "$@"
