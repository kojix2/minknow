SHELL := /usr/bin/env bash

OUT_DIR := src/generated
PROTO_ROOT := minknow_api/proto
API_ROOT := $(PROTO_ROOT)/minknow_api

PROTO_PLUGIN ?= lib/proto/bin/protoc-gen-crystal
GRPC_PLUGIN ?= lib/grpc/bin/protoc-gen-crystal-grpc

PROTO_FILES := $(shell find $(API_ROOT) -type f -name '*.proto' | sort)

.PHONY: help setup gen-tools gen gen-selected

help:
	@echo "Targets:"
	@echo "  make setup                          Install shard dependencies"
	@echo "  make gen-tools                      Build protoc plugins"
	@echo "  make gen                            Generate all minknow_api proto files"
	@echo "  make gen-selected PROTOS='minknow_api/manager.proto minknow_api/acquisition.proto'"

setup: lib/proto/shard.yml lib/grpc/shard.yml
setup:
	@if [[ ! -f lib/proto/shard.yml || ! -f lib/grpc/shard.yml || shard.yml -nt lib/proto/shard.yml || shard.lock -nt lib/proto/shard.yml || shard.yml -nt lib/grpc/shard.yml || shard.lock -nt lib/grpc/shard.yml ]]; then \
		shards install; \
	fi

gen-tools: setup $(PROTO_PLUGIN) $(GRPC_PLUGIN)

$(PROTO_PLUGIN): lib/proto/src/protoc-gen-crystal_main.cr
	@mkdir -p $(dir $@)
	crystal build lib/proto/src/protoc-gen-crystal_main.cr -o $@

$(GRPC_PLUGIN): lib/grpc/src/protoc-gen-crystal-grpc_main.cr
	@mkdir -p $(dir $@)
	crystal build lib/grpc/src/protoc-gen-crystal-grpc_main.cr -o $@

gen: gen-tools
	@mkdir -p $(OUT_DIR)
	protoc --proto_path=$(PROTO_ROOT) --plugin=protoc-gen-crystal=$(PROTO_PLUGIN) --crystal_out=$(OUT_DIR) $(PROTO_FILES)
	protoc --proto_path=$(PROTO_ROOT) --plugin=protoc-gen-crystal-grpc=$(GRPC_PLUGIN) --crystal-grpc_out=$(OUT_DIR) $(PROTO_FILES)

gen-selected: gen-tools
	@test -n "$(PROTOS)" || (echo "Specify PROTOS, e.g. PROTOS='minknow_api/manager.proto'"; exit 1)
	@mkdir -p $(OUT_DIR)
	protoc --proto_path=$(PROTO_ROOT) --plugin=protoc-gen-crystal=$(PROTO_PLUGIN) --crystal_out=$(OUT_DIR) $(PROTOS)
	protoc --proto_path=$(PROTO_ROOT) --plugin=protoc-gen-crystal-grpc=$(GRPC_PLUGIN) --crystal-grpc_out=$(OUT_DIR) $(PROTOS)
