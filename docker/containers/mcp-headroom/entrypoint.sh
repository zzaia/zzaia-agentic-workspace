#!/bin/sh
set -eu

exec supergateway --port 3008 --outputTransport streamableHttp --stateful --stdio "headroom mcp serve --proxy-url http://ml-server:8787"