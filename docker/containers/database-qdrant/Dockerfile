FROM busybox:1.37 AS busybox
FROM qdrant/qdrant:v1.17.1
COPY --from=busybox /bin/wget /bin/wget

RUN groupadd -r qdrant && useradd -r -g qdrant qdrant \
  && mkdir -p /qdrant/storage \
  && chown -R qdrant:qdrant /qdrant

USER qdrant
