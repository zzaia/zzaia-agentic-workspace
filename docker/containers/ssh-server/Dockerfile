FROM zzaia-workspace-base:latest

ARG SSH_PORT=2222

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/*

COPY docker/sshd_config /etc/ssh/sshd_config.d/workspace.conf
RUN sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config.d/workspace.conf \
    && grep -q 'Include.*sshd_config.d' /etc/ssh/sshd_config \
    || echo 'Include /etc/ssh/sshd_config.d/*.conf' >> /etc/ssh/sshd_config \
    && echo "${SSH_PORT}" > /etc/ssh-port

COPY docker/containers/ssh-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${SSH_PORT}

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=5 \
    CMD bash -c "</dev/tcp/localhost/$(cat /etc/ssh-port)"

ENTRYPOINT ["/entrypoint.sh"]
