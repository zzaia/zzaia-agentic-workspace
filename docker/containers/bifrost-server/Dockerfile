FROM maximhq/bifrost:latest

RUN apt-get update && apt-get install -y --no-install-recommends bash jq wget && rm -rf /var/lib/apt/lists/*

COPY docker/containers/bifrost-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY docker/containers/bifrost-server/config.json /config.json

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
