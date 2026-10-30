SHELL := /usr/bin/env bash

OUT_DIR ?= src/generated
PROTO_ROOT := minknow_api/proto
API_ROOT := $(PROTO_ROOT)/minknow_api
PROTOC ?= protoc

PROTO_PLUGIN ?= lib/proto/bin/protoc-gen-crystal
GRPC_PLUGIN ?= lib/grpc/bin/protoc-gen-crystal-grpc

PROTO_FILES = $(shell find $(API_ROOT) $(PROTO_ROOT)/util -type f -name '*.proto' 2>/dev/null | sort)
WELL_KNOWN_PROTOS := google/protobuf/any.proto \
	google/protobuf/descriptor.proto \
	google/protobuf/duration.proto \
	google/protobuf/empty.proto \
	google/protobuf/timestamp.proto \
	google/protobuf/wrappers.proto
GOOGLE_RPC_PROTOS := google/rpc/status.proto
PROTO_PATHS := --proto_path=$(PROTO_ROOT) --proto_path=vendor

.PHONY: help setup gen-tools gen gen-one gen-well-known gen-raw gen-one-raw gen-fmt

help:
	@echo "Targets:"
	@echo "  make setup                          Install shard dependencies"
	@echo "  make gen-tools                      Build protoc plugins"
	@echo "  make gen                            Generate all proto files and format"
	@echo "  make gen-well-known                 Generate bundled Google protobuf types"
	@echo "  make gen-one PROTOS='minknow_api/manager.proto minknow_api/acquisition.proto'"
	@echo "                                      Generate selected proto files and format"
	@echo "  make gen-raw                        Generate all proto files (no format)"
	@echo "  make gen-one-raw PROTOS='minknow_api/manager.proto minknow_api/acquisition.proto'"
	@echo "                                      Generate selected proto files (no format)"
	@echo "  make gen-fmt                        Format generated Crystal files"

setup:
	shards check || shards install --frozen

gen-tools: setup
	@mkdir -p $(dir $(PROTO_PLUGIN)) $(dir $(GRPC_PLUGIN))
	crystal build lib/proto/src/protoc-gen-crystal_main.cr -o $(PROTO_PLUGIN)
	crystal build lib/grpc/src/protoc-gen-crystal-grpc_main.cr -o $(GRPC_PLUGIN)

gen: gen-raw
	$(MAKE) gen-fmt

gen-one: gen-one-raw
	$(MAKE) gen-fmt

gen-well-known: gen-tools
	@mkdir -p $(OUT_DIR)
	$(PROTOC) --proto_path=vendor --plugin=protoc-gen-crystal=$(PROTO_PLUGIN) --crystal_out=$(OUT_DIR) $(WELL_KNOWN_PROTOS)
	crystal tool format $(OUT_DIR)/google/protobuf

gen-raw: gen-tools
	@test -n "$(PROTO_FILES)" || (echo "Initialize API inputs with git submodule update --init minknow_api"; exit 1)
	@mkdir -p $(OUT_DIR)
	$(PROTOC) $(PROTO_PATHS) --plugin=protoc-gen-crystal=$(PROTO_PLUGIN) --crystal_out=$(OUT_DIR) $(WELL_KNOWN_PROTOS) $(GOOGLE_RPC_PROTOS) $(PROTO_FILES)
	$(PROTOC) $(PROTO_PATHS) --plugin=protoc-gen-crystal-grpc=$(GRPC_PLUGIN) --crystal-grpc_out=$(OUT_DIR) $(PROTO_FILES)

gen-one-raw: gen-tools
	@test -n "$(PROTOS)" || (echo "Specify PROTOS, e.g. PROTOS='minknow_api/manager.proto'"; exit 1)
	@mkdir -p $(OUT_DIR)
	$(PROTOC) $(PROTO_PATHS) --plugin=protoc-gen-crystal=$(PROTO_PLUGIN) --crystal_out=$(OUT_DIR) $(WELL_KNOWN_PROTOS) $(GOOGLE_RPC_PROTOS) $(PROTOS)
	$(PROTOC) $(PROTO_PATHS) --plugin=protoc-gen-crystal-grpc=$(GRPC_PLUGIN) --crystal-grpc_out=$(OUT_DIR) $(PROTOS)

gen-fmt:
	crystal tool format $(OUT_DIR)
