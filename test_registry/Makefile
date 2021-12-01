.PHONY: registry clean_registry

all: clean_registry registry

registry:
	docker-compose -f simple.yml up -d

clean_registry:
	docker-compose -f simple.yml down -v
