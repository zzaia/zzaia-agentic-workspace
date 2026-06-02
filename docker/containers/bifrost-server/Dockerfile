FROM maximhq/bifrost:latest

USER root
RUN apk add --no-cache bash jq curl python3

COPY docker/containers/bifrost-server/entrypoint.sh /entrypoint.sh
COPY docker/containers/bifrost-server/auth_proxy.py /auth_proxy.py
RUN chmod +x /entrypoint.sh && mkdir -p /app/data

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
