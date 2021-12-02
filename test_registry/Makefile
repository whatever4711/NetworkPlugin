#!/usr/bin/make -f
COMPOSE_YML=simple.yml
REGISTRY_IMAGE=registry:2.7
REGISTRY_UI_IMAGE=jc21/registry-ui:latest
REGISTRY_PORT=5000
REGISTRY_UI_PORT=80

.PHONY: registry clean_registry

all: clean_registry registry

registry:
	docker volume create registry-data
	docker network create registry-nw
	docker run -d --name registry --network registry-nw -p $(REGISTRY_PORT):5000 -v registry-data:/var/lib/registry -v $(CURDIR)/config/simple.yml:/etc/docker/registry/config.yml $(REGISTRY_IMAGE)
	docker run -d --name registry_ui --network registry-nw -p $(REGISTRY_UI_PORT):80 -e REGISTRY_SSL=false -e REGISTRY_STORAGE_DELETE_ENABLED=true -e REGISTRY_HOST=registry:5000 $(REGISTRY_UI_IMAGE)

clean_registry:
	docker stop registry registry_ui || true
	docker rm registry registry_ui || true
	docker volume rm registry-data || true
	docker network rm registry-nw || true
