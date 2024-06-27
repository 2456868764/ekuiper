BUILD_PATH ?= _build
PACKAGES_PATH ?= _packages

VERSION := $(shell git describe --tags --always | sed 's/^v//g')
ARCH := $(shell go env GOARCH)
OS := $(shell go env GOOS)
PACKAGE_NAME := kuiper-$(VERSION)-$(OS)-$(ARCH)
GO              := GO111MODULE=on go

FAILPOINT_ENABLE  := find $$PWD/ -type d | grep -vE "(\.git|tools)" | xargs tools/failpoint/bin/failpoint-ctl enable
FAILPOINT_DISABLE := find $$PWD/ -type d | grep -vE "(\.git|tools)" | xargs tools/failpoint/bin/failpoint-ctl disable

# Images management
REGISTRY ?= registry.cn-hangzhou.aliyuncs.com
REGISTRY_NAMESPACE?= 2456868764
REGISTRY_USER_NAME?=""
REGISTRY_PASSWORD?=""

## docker buildx support platform
PLATFORMS ?= linux/arm64,linux/amd64

# Image URL to use all building/pushing image targets
GIT_VERSION ?= $(shell git describe --tags --always)
EKUIPERD_IMG ?= ${REGISTRY}/${REGISTRY_NAMESPACE}/ekuiperd:${GIT_VERSION}


TARGET ?= lfedge/ekuiper

export KUIPER_SOURCE := $(shell pwd)

.PHONY: build
build: build_without_edgex

.PHONY:pkg
pkg: pkg_without_edgex
	@if [ "$$(uname -s)" = "Linux" ]; then make -C deploy/packages; fi

.PHONY: build_prepare
build_prepare:
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/etc
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/etc/sources
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/etc/sinks
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/etc/services
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/etc/services/schemas
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/data
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/plugins
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/plugins/sources
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/plugins/sinks
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/plugins/functions
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/plugins/portable
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/plugins/wasm
	@mkdir -p $(BUILD_PATH)/$(PACKAGE_NAME)/log

	@cp -r etc/* $(BUILD_PATH)/$(PACKAGE_NAME)/etc

.PHONY: build_without_edgex
build_without_edgex: build_prepare
	GO111MODULE=on CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -o kuiper cmd/kuiper/main.go
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiper; upx ./kuiperd; fi
	@mv ./kuiper ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@echo "Build successfully"

.PHONY: pkg_without_edgex
pkg_without_edgex: build_without_edgex
	@make real_pkg

.PHONY: build_with_edgex
build_with_edgex: build_prepare
	GO111MODULE=on CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "edgex include_nats_messaging" -o kuiper cmd/kuiper/main.go
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "edgex include_nats_messaging" -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiper; upx ./kuiperd; fi
	@mv ./kuiper ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@echo "Build successfully"

.PHONY: build_with_edgex_and_script
build_with_edgex_and_script: build_prepare
	GO111MODULE=on CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "edgex include_nats_messaging" -o kuiper cmd/kuiper/main.go
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "edgex include_nats_messaging script" -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiper; upx ./kuiperd; fi
	@mv ./kuiper ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@echo "Build successfully"

.PHONY: pkg_with_edgex
pkg_with_edgex: build_with_edgex
	@make real_pkg

.PHONY: build_with_fdb
build_with_fdb: build_prepare
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "fdb" -o kuiper cmd/kuiper/main.go
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "fdb" -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiper; upx ./kuiperd; fi
	@mv ./kuiper ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@echo "Build successfully"

.PHONY: pkg_with_fdb
pkg_with_fdb: build_with_fdb
	@make real_pkg

.PHONY: build_core
build_core: build_prepare
	GO111MODULE=on CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags core -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiperd; fi
	@mv ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@echo "Build successfully"

PLUGINS_IN_FULL := \
	extensions/sinks/influx \
	extensions/sinks/influx2 \
	extensions/sinks/kafka \
	extensions/sinks/image \
	extensions/sinks/sql   \
	extensions/sources/random \
	extensions/sources/sql \
	extensions/sources/video \
	extensions/sources/kafka

.PHONY: build_full
build_full: SHELL:=/bin/bash -euo pipefail
build_full: build_prepare
	GO111MODULE=on CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -o kuiper cmd/kuiper/main.go
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "full include_nats_messaging" -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiper; upx ./kuiperd; fi
	@mv ./kuiper ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@while read plugin; do \
		while read line; do \
			type=$$(echo $$(dirname $$line) | cut -d'/' -f2); \
			cp -r $$line $(BUILD_PATH)/$(PACKAGE_NAME)/etc/$$type/$$(basename $$line); \
		done < <(find $$plugin -type f \( -name "*.json" -o -name "*.yaml" \)); \
	done < <(echo $(PLUGINS_IN_FULL))
	@echo "Build successfully"

.PHONY: pkg_core
pkg_core: build_core
	@mkdir -p $(PACKAGES_PATH)
	@cd $(BUILD_PATH) && zip -rq $(PACKAGE_NAME)-core.zip $(PACKAGE_NAME)
	@cd $(BUILD_PATH) && tar -czf $(PACKAGE_NAME)-core.tar.gz $(PACKAGE_NAME)
	@mv $(BUILD_PATH)/$(PACKAGE_NAME)-core.zip $(BUILD_PATH)/$(PACKAGE_NAME)-core.tar.gz $(PACKAGES_PATH)
	@echo "Package core success"

.PHONY: pkg_full
pkg_full: build_full
	@mkdir -p $(PACKAGES_PATH)
	@cd $(BUILD_PATH) && zip -rq $(PACKAGE_NAME)-full.zip $(PACKAGE_NAME)
	@cd $(BUILD_PATH) && tar -czf $(PACKAGE_NAME)-full.tar.gz $(PACKAGE_NAME)
	@mv $(BUILD_PATH)/$(PACKAGE_NAME)-full.zip $(BUILD_PATH)/$(PACKAGE_NAME)-full.tar.gz $(PACKAGES_PATH)
	@echo "Package full success"

.PHONY: real_pkg
real_pkg:
	@mkdir -p $(PACKAGES_PATH)
	@cd $(BUILD_PATH) && zip -rq $(PACKAGE_NAME).zip $(PACKAGE_NAME)
	@cd $(BUILD_PATH) && tar -czf $(PACKAGE_NAME).tar.gz $(PACKAGE_NAME)
	@mv $(BUILD_PATH)/$(PACKAGE_NAME).zip $(BUILD_PATH)/$(PACKAGE_NAME).tar.gz $(PACKAGES_PATH)
	@echo "Package build success"

.PHONY: build_with_wasm
build_with_wasm: build_prepare
	GO111MODULE=on CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -o kuiper cmd/kuiper/main.go
	GO111MODULE=on CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "wasmedge" -o kuiperd cmd/kuiperd/main.go
	@if [ "$$(uname -s)" = "Linux" ] && [ ! -z $$(which upx) ]; then upx ./kuiper; upx ./kuiperd; fi
	@mv ./kuiper ./kuiperd $(BUILD_PATH)/$(PACKAGE_NAME)/bin
	@echo "Build successfully"


.PHONY: build-kuiperd
build-kuiperd:
	@rm -f -R deploy/docker/_build
	@mkdir -p deploy/docker/_build/bin
	@mkdir -p deploy/docker/_build/etc
	@mkdir -p deploy/docker/_build/etc/sources
	@mkdir -p deploy/docker/_build/etc/sinks
	@mkdir -p deploy/docker/_build/etc/services
	@mkdir -p deploy/docker/_build/etc/services/schemas
	@mkdir -p deploy/docker/_build/data
	@mkdir -p deploy/docker/_build/plugins
	@mkdir -p deploy/docker/_build/plugins/sources
	@mkdir -p deploy/docker/_build/plugins/sinks
	@mkdir -p deploy/docker/_build/plugins/functions
	@mkdir -p deploy/docker/_build/plugins/portable
	@mkdir -p deploy/docker/_build/plugins/wasm
	@mkdir -p deploy/docker/_build/log

	@cp -r etc.b/* deploy/docker/_build/etc

	GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "full include_nats_messaging" -o deploy/docker/amd64/kuiperd cmd/kuiperd/main.go
	GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w -X github.com/lf-edge/ekuiper/cmd.Version=$(VERSION) -X github.com/lf-edge/ekuiper/cmd.LoadFileType=relative" -tags "full include_nats_messaging" -o deploy/docker/arm64/kuiperd cmd/kuiperd/main.go

.PHONY: image-buildx-ekuiperd
image-buildx-ekuiperd: build-kuiperd  ## Build and push docker image for the dubbo client for cross-platform support
	# copy existing Dockerfile and insert --platform=${BUILDPLATFORM} into Dockerfile.cross, and preserve the original Dockerfile

	sed -e '1 s/\(^FROM\)/FROM --platform=\$$\{BUILDPLATFORM\}/; t' -e ' 1,// s//FROM --platform=\$$\{BUILDPLATFORM\}/' deploy/docker/Dockerfile-kuiperd > deploy/docker/Dockerfile.cross
	- docker buildx create --name project-client-builder
	docker buildx use project-client-builder
	- docker buildx build --build-arg --push --output=type=registry --platform=$(PLATFORMS) --tag ${EKUIPERD_IMG} -f deploy/docker/Dockerfile.cross deploy/docker
	- docker buildx rm project-client-builder
	rm deploy/docker/Dockerfile.cross && rm -f -R deploy/docker/arm64/ &&  rm -f -R deploy/docker/amd64/ &&  rm -f -R deploy/docker/_build


.PHONY: docker
docker:
	docker buildx build --no-cache --platform=linux/amd64 -t $(TARGET):$(VERSION) -f deploy/docker/Dockerfile . --load
	docker buildx build --no-cache --platform=linux/amd64 -t $(TARGET):$(VERSION)-slim -f deploy/docker/Dockerfile-slim . --load
	docker buildx build --no-cache --platform=linux/amd64 -t $(TARGET):$(VERSION)-full -f deploy/docker/Dockerfile-full . --load
	docker buildx build --no-cache --platform=linux/amd64 -t $(TARGET):$(VERSION)-dev -f deploy/docker/Dockerfile-dev . --load

PLUGINS := sinks/influx \
	sinks/influx2 \
	sinks/zmq \
	sinks/kafka \
	sinks/image \
	sinks/sql   \
	sources/random \
	sources/zmq \
	sources/sql \
	sources/video \
	sources/kafka \
	sinks/tdengine \
	functions/accumulateWordCount \
	functions/countPlusOne \
	functions/image \
	functions/geohash \
	functions/echo \
	functions/labelImage \
	functions/tfLite

.PHONY: plugins $(PLUGINS)
plugins: $(PLUGINS)

$(PLUGINS): PLUGIN_TYPE = $(word 1, $(subst /, , $@))
$(PLUGINS): PLUGIN_NAME = $(word 2, $(subst /, , $@))
$(PLUGINS):
	@$(CURDIR)/build-plugins.sh $(PLUGIN_TYPE) $(PLUGIN_NAME)

.PHONY: clean
clean:
	@rm -rf cross_build.tar linux_amd64 linux_arm64 linux_arm_v7 linux_386
	@rm -rf _build _packages _plugins

tidy:
	@echo "go mod tidy"
	go mod tidy && git diff go.mod go.sum

lint:tools/lint/bin/golangci-lint
	@echo "linting"
	tools/lint/bin/golangci-lint run ./... ./extensions/... ./tools/kubernetes/...
	cd sdk/go && ../../tools/lint/bin/golangci-lint run

tools/lint/bin/golangci-lint:
	GOBIN=tools/lint/bin go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

tools/failpoint/bin/failpoint-ctl:
	GOBIN=$(shell pwd)/tools/failpoint/bin $(GO) install github.com/pingcap/failpoint/failpoint-ctl@2eaa328

failpoint-enable: tools/failpoint/bin/failpoint-ctl
# Converting gofail failpoints...
	@$(FAILPOINT_ENABLE)

failpoint-disable: tools/failpoint/bin/failpoint-ctl
# Restoring gofail failpoints...
	@$(FAILPOINT_DISABLE)
