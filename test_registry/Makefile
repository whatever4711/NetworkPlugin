#!/usr/bin/make -f
COMPOSE_YML=simple.yml

.PHONY: registry clean_registry

all: clean_registry registry

registry:
	docker-compose -f $(COMPOSE_YML) up -d

clean_registry:
	docker-compose -f $(COMPOSE_YML) down -v 
