.PHONY: ext ext-debug clean help

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

## Remove compiled artefacts
clean:
	rm -rf gp_extension/target $(BIN_DIR)

help:
	@echo "Targets:"
	@echo "  ext        — build release GDExtension and copy to addons/"
	@echo "  ext-debug  — build debug GDExtension and copy to addons/"
	@echo "  clean      — remove all build artefacts"
