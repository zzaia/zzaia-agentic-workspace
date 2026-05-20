#!/bin/sh
set -eu

exec npx -y supergateway@latest --port 3008 --outputTransport streamableHttp --stateful --stdio "headroom mcp serve --proxy-url http://ml-server:8787"