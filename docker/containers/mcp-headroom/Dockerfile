FROM ghcr.io/chopratejas/headroom:latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends nodejs npm \
  && npm install -g supergateway@3.4.3 @opentelemetry/auto-instrumentations-node \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd -r headroom && useradd -r -g headroom headroom \
  && chown -R headroom:headroom /usr/local/lib/node_modules /usr/local/bin/supergateway

COPY docker/containers/mcp-headroom/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER headroom
ENTRYPOINT ["/entrypoint.sh"]