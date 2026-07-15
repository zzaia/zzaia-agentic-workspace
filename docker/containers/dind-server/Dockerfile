FROM debian:bookworm-slim

# Install dependencies and Docker CE
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    gnupg \
    iptables \
    libltdl7 \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/debian bookworm stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && rm -rf /var/lib/apt/lists/*

# Install NVIDIA Container Toolkit at build time
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nvidia-container-toolkit \
    && rm -rf /var/lib/apt/lists/*

# Install Kind and kubectl as static binaries
RUN curl -fsSL -o /usr/local/bin/kind \
        "https://github.com/kubernetes-sigs/kind/releases/download/v0.32.0/kind-linux-amd64" \
    && chmod +x /usr/local/bin/kind \
    && curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# Create Kind config directory and copy cluster configuration
RUN mkdir -p /etc/kind
COPY kind-config.yaml /etc/kind/kind-config.yaml
RUN curl -fsSL -o /etc/kind/portainer-agent-k8s-nodeport.yaml \
        "https://downloads.portainer.io/ce-lts/portainer-agent-k8s-nodeport.yaml"

VOLUME /var/lib/docker
EXPOSE 2375 2376

COPY entrypoint.sh /usr/local/bin/docker-entrypoint-nvidia.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-nvidia.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-nvidia.sh"]
CMD ["dockerd"]
