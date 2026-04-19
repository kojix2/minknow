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


lib/proto/shard.yml lib/grpc/shard.yml: shard.yml shard.lock
	shards install

gen-tools: $(PROTO_PLUGIN) $(GRPC_PLUGIN)

$(PROTO_PLUGIN): lib/proto/shard.yml lib/proto/src/protoc-gen-crystal_main.cr
	@mkdir -p $(dir $@)
	crystal build lib/proto/src/protoc-gen-crystal_main.cr -o $@

$(GRPC_PLUGIN): lib/grpc/shard.yml lib/grpc/src/protoc-gen-crystal-grpc_main.cr
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
