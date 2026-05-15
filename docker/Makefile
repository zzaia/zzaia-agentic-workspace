.PHONY: build build-base

build: build-base
	docker compose build

build-base:
	docker compose build workspace-base

up: build-base
	docker compose build
	docker compose up -d
