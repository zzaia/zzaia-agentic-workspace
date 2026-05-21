FROM docker:28.1.1-dind

# Install prerequisites for NVIDIA Container Toolkit
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    gnupg \
    libltdl

# Add custom entrypoint that optionally installs NVIDIA Container Toolkit at runtime
COPY entrypoint.sh /usr/local/bin/docker-entrypoint-nvidia.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-nvidia.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-nvidia.sh"]
CMD ["dockerd"]
