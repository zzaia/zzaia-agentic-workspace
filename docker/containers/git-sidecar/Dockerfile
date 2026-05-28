FROM alpine:3.21

RUN apk add --no-cache openssh git wget

RUN addgroup -g 1000 git && \
    adduser -D -u 1000 -G git -s /usr/bin/git-shell -h /home/git git

COPY docker/containers/git-sidecar/entrypoint.sh /entrypoint.sh
COPY docker/containers/git-sidecar/git-proxy-cmd.sh /usr/local/bin/git-proxy-cmd

RUN chmod +x /entrypoint.sh /usr/local/bin/git-proxy-cmd

EXPOSE 2223

ENTRYPOINT ["/entrypoint.sh"]
