#!/usr/bin/make -f

PLUGIN_NAME=localhost:5000/kathara/katharanp
PLUGIN_CONTAINER=katharanp
ARCHITECTURES=amd64 arm64

.PHONY: all test clean gobuild image plugin

all_arm64: test clean_arm64 gobuild_docker_arm64 image_arm64 plugin_arm64
all_push_arm64: all_arm64 push_arm64

all_amd64: test clean_amd64 gobuild_docker_amd64 image_amd64 plugin_amd64
all_push_amd64: all_amd64 push_amd64

test:
	cat ./plugin-src/config.json | python3 -m json.tool

clean_%:
	docker plugin rm -f ${PLUGIN_NAME}:$* || true
	docker rm -f ${PLUGIN_CONTAINER}_rootfs || true
	docker buildx rm kat-np-builder || true
	rm -rf ./img-src/katharanp
	rm -rf ./go-src/katharanp
	rm -rf ./plugin-src/rootfs

gobuild_docker_%:
	docker run -ti --rm -v `pwd`/go-src/:/root/go-src golang:alpine3.14 /bin/sh -c "apk add -U make && cd /root/go-src && make gobuild_$*"

image_%: gobuild_docker_% buildx_create_environment
	mv ./go-src/katharanp ./img-src/
	docker buildx build --platform linux/$* --load -t ${PLUGIN_CONTAINER}:rootfs ./img-src/
	docker create --name ${PLUGIN_CONTAINER}_rootfs ${PLUGIN_CONTAINER}:rootfs
	mkdir -p ./plugin-src/rootfs
	docker export ${PLUGIN_CONTAINER}_rootfs | tar -x -C ./plugin-src/rootfs
	docker rm -vf ${PLUGIN_CONTAINER}_rootfs
	docker rmi ${PLUGIN_CONTAINER}:rootfs

plugin_%: image
	docker plugin create ${PLUGIN_NAME}:$* ./plugin-src/
	rm -rf ./plugin-src/rootfs

push_%: plugin
	docker plugin push ${PLUGIN_NAME}:$*

buildx_create_environment:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker buildx create --name kat-np-builder --use
	docker buildx inspect --bootstrap

registry:
	docker-compose -f ./test_registry/simple.yml up -d

clean_registry:
	docker-compose -f ./test_registry/simple.yml down -v

manifest:
#	@wget -O docker https://6582-88013053-gh.circle-artifacts.com/1/work/build/docker-linux-amd64
#	@chmod +x docker
	#@./docker login -u $(DOCKER_USER) -p $(DOCKER_PASS)
	docker manifest create --insecure --amend $(PLUGIN_NAME):latest $(foreach arch,$(ARCHITECTURES), $(PLUGIN_NAME):$(arch))
	$(foreach arch,$(ARCHITECTURES), docker manifest annotate $(PLUGIN_NAME):latest $(PLUGIN_NAME):$(arch) --os linux $(strip $(call convert_variants,$(arch)));)
	docker manifest push $(PLUGIN_NAME):latest
	#@rm -f docker
	#@./docker logout

define convert_variants
	$(shell echo $(1) | sed -e "s|amd64|--arch amd64|g" -e "s|arm32|--arch arm --variant v7|g" -e "s|arm64|--arch arm64 --variant v8|g")
endef
