.PHONY: ext ext-debug test clean help

UNAME := $(shell uname -s)
BIN_DIR := addons/gp_extension/bin

ifeq ($(UNAME), Linux)
  LIB_NAME := libgp_extension.so
else ifeq ($(UNAME), Darwin)
  LIB_NAME := libgp_extension.dylib
else
  LIB_NAME := gp_extension.dll
endif

## Build the GDExtension in release mode and copy it to addons/
ext:
	cd gp_extension && cargo build --release
	mkdir -p $(BIN_DIR)
	cp gp_extension/target/release/$(LIB_NAME) $(BIN_DIR)/$(LIB_NAME)
	@echo "✓  GDExtension ready at $(BIN_DIR)/$(LIB_NAME)"

## Build in debug mode (faster compile, larger binary)
ext-debug:
	cd gp_extension && cargo build
	mkdir -p $(BIN_DIR)
	cp gp_extension/target/debug/$(LIB_NAME) $(BIN_DIR)/$(LIB_NAME)
	@echo "✓  GDExtension (debug) ready at $(BIN_DIR)/$(LIB_NAME)"

## Run Rust unit + integration tests (parses the real GP5 test song)
test-rust:
	cd gp_extension && cargo test

## Run Godot headless scene tests (requires Godot 4.4+ in PATH as 'godot')
test-godot:
	godot --headless --path . --script res://tests/test_runner.gd

## Run all tests
test: test-rust test-godot

## Remove compiled artefacts
clean:
	rm -rf gp_extension/target $(BIN_DIR)

help:
	@echo "Targets:"
	@echo "  ext          — build release GDExtension and copy to addons/"
	@echo "  ext-debug    — build debug   GDExtension and copy to addons/"
	@echo "  test-rust    — run Rust unit + integration tests"
	@echo "  test-godot   — run Godot headless scene tests (needs Godot 4.4)"
	@echo "  test         — run all tests"
	@echo "  clean        — remove all build artefacts"
