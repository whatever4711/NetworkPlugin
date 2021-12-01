#!/usr/bin/make -f

PLUGIN_NAME=localhost:5000/kathara/katharanp
PLUGIN_CONTAINER=katharanp
VERSION=latest
ARCHITECTURES=amd64 386 arm64v8 armv7 armv6 ppc64le s390x

.PHONY: all all_push test clean gobuild image plugin

all: test
	$(foreach arch,$(ARCHITECTURES), $(MAKE) clean_$(arch) gobuild_docker_$(arch) image_$(arch) plugin_$(arch);)

all_push: all
	$(foreach arch,$(ARCHITECTURES), $(MAKE) push_$(arch);)

test:
	cat ./plugin-src/config.json | python3 -m json.tool

clean_%:
	docker plugin rm -f ${PLUGIN_NAME}:$*-${VERSION} || true
	docker rm -f ${PLUGIN_CONTAINER}_rootfs || true
	docker buildx rm kat-np-builder || true
	rm -rf ./img-src/katharanp
	rm -rf ./go-src/katharanp
	rm -rf ./plugin-src/rootfs

gobuild_docker_%:
	docker run -ti --rm -v `pwd`/go-src/:/root/go-src golang:alpine3.14 /bin/sh -c "apk add -U make && cd /root/go-src && make gobuild_$(strip $(call goarch,$*))"

image_%: gobuild_docker_% buildx_create_environment
	mv ./go-src/katharanp ./img-src/
	docker buildx build --platform linux/$(strip $(call convert_archs, $*)) --load -t ${PLUGIN_CONTAINER}:rootfs ./img-src/
	docker create --name ${PLUGIN_CONTAINER}_rootfs ${PLUGIN_CONTAINER}:rootfs
	mkdir -p ./plugin-src/rootfs
	docker export ${PLUGIN_CONTAINER}_rootfs | tar -x -C ./plugin-src/rootfs
	docker rm -vf ${PLUGIN_CONTAINER}_rootfs
	docker rmi ${PLUGIN_CONTAINER}:rootfs

plugin_%: image
	docker plugin create ${PLUGIN_NAME}:$*-${VERSION} ./plugin-src/
	rm -rf ./plugin-src/rootfs

push_%: plugin
	docker plugin push ${PLUGIN_NAME}:$*-${VERSION}

buildx_create_environment:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker buildx create --name kat-np-builder --use
	docker buildx inspect --bootstrap

registry:
	@$(MAKE) -C ./test_registry

manifest: clean_manifest
#	@wget -O docker https://6582-88013053-gh.circle-artifacts.com/1/work/build/docker-linux-amd64
#	@chmod +x docker
#	docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}
	docker manifest create --insecure --amend ${PLUGIN_NAME}:latest $(foreach arch,${ARCHITECTURES}, ${PLUGIN_NAME}:${arch}-${VERSION})
	$(foreach arch,${ARCHITECTURES}, docker manifest annotate ${PLUGIN_NAME}:latest ${PLUGIN_NAME}:${arch}-${VERSION} --os linux $(strip $(call convert_variants,${arch}));)
	docker manifest push ${PLUGIN_NAME}:latest
	#@rm -f docker
	#@./docker logout

clean_manifest:
	docker manifest rm $(PLUGIN_NAME):latest || true

define convert_archs
	$(shell echo $(1) | sed -e "s|\(arm[64]*\).*\(v[6-8]\)|\1/\2|g")
endef


define convert_variants
	$(shell echo $(1) | sed -e "s|\(.*\)|--arch \1|g; s|\(arm[64]*\).*\(v[6-8]\)|\1 --variant \2|g")
endef

define goarch
	$(shell echo $(1) | sed -e "s|\(arm[64]*\)v.*|\1|g" )
endef
