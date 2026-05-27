FROM ubuntu:24.04

ARG JUPYTER_PORT=8888

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    BROWSER=/usr/local/bin/browser-print \
    PATH=/opt/tools/miniforge3/envs/venv-analytics/bin:/opt/tools/miniforge3/bin:/opt/tools/.local/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install ansible-core --break-system-packages

RUN printf '#!/bin/sh\necho ""\necho "Open this URL in your browser:"\necho "  $1"\necho ""\n' \
        > /usr/local/bin/browser-print \
    && chmod +x /usr/local/bin/browser-print

RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 user

COPY docker/containers/jupyter-sidecar/entrypoint.sh /entrypoint.sh
COPY docker/containers/jupyter-sidecar/scripts/versions.env /opt/scripts/versions.env
RUN chmod +x /entrypoint.sh

COPY docker/containers/jupyter-sidecar/ansible /usr/local/lib/zzaia/ansible
RUN find /usr/local/lib/zzaia/ansible -name '*.yml' -exec chmod 644 {} + \
    && find /usr/local/lib/zzaia/ansible -name '*.ini' -exec chmod 644 {} + \
    && find /usr/local/lib/zzaia/ansible -name '*.cfg' -exec chmod 644 {} +

WORKDIR /home/user
USER user

EXPOSE ${JUPYTER_PORT}

HEALTHCHECK --interval=15s --timeout=5s --retries=5 --start-period=30m \
    CMD curl -sf http://localhost:${JUPYTER_PORT:-8888}/api >/dev/null

ENTRYPOINT ["/entrypoint.sh"]
