.PHONY: k8s-images k8s-images-nopush k8s-list help

# Extra flags forwarded to build-images.sh, e.g.:
#   make k8s-images ARGS="--tag 1.2.3 mlServer mcpGithub"
ARGS ?=

help:
	@echo "Kubernetes image pipeline:"
	@echo "  make k8s-images         Build + push every zzaia-* image, pin tags in a Helm overlay"
	@echo "  make k8s-images-nopush  Build only (no registry push, no overlay)"
	@echo "  make k8s-list           List the buildable image keys"
	@echo "  ARGS=\"...\"               Extra flags forwarded to deploy/k8s/build-images.sh"

# Builds from containers/*/Dockerfile, pushes to the local registry, and writes
# deploy/k8s/Chart/values-images.yaml pinning images.<name>.tag. See
# ../deploy/k8s/README.md. Override registry/tag/alias via ARGS or env
# (REGISTRY=, TAG=, ALIAS=).
k8s-images:
	bash ../deploy/k8s/build-images.sh $(ARGS)

k8s-images-nopush:
	bash ../deploy/k8s/build-images.sh --no-push $(ARGS)

k8s-list:
	bash ../deploy/k8s/build-images.sh --list
