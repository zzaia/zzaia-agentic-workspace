FROM zzaia-workspace-base:latest

COPY docker/devcontainer.json /opt/zzaia/home-seed/.devcontainer/devcontainer.json
COPY docker/containers/containers-dev-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
