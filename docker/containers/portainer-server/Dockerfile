FROM alpine:3.20
RUN apk add --no-cache curl python3
COPY --from=portainer/portainer-ce:latest /portainer /portainer
COPY --from=portainer/portainer-ce:latest /public /public
COPY --from=portainer/portainer-ce:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY docker/containers/portainer-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /portainer
VOLUME /data
EXPOSE 9000 8000 9443
ENTRYPOINT ["/entrypoint.sh"]
