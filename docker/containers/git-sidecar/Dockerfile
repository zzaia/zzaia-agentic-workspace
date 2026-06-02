FROM alpine:3.21

RUN apk add --no-cache bash openssh git wget jq

RUN addgroup -g 1000 git && \
    adduser -D -u 1000 -G git -s /bin/sh -h /home/git git && \
    # Ensure git user can login (unlock account)
    passwd -u git 2>/dev/null || true

COPY docker/containers/git-sidecar/sshd_config /etc/ssh/sshd_config
COPY docker/containers/git-sidecar/common.sh /app/common.sh
COPY docker/containers/git-sidecar/entrypoint.sh /app/entrypoint.sh
COPY docker/containers/git-sidecar/git-proxy-cmd.sh /usr/local/bin/git-proxy-cmd

RUN mkdir -p /app && \
    chmod +x /app/entrypoint.sh /usr/local/bin/git-proxy-cmd /app/common.sh && \
    chmod 600 /etc/ssh/sshd_config && \
    ln -s /app/common.sh /usr/local/bin/common.sh

EXPOSE 2223

ENTRYPOINT ["/app/entrypoint.sh"]
