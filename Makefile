# go-guitar Makefile
.PHONY: all setup ext test-rust test-godot clean

# The pre-compiled libgp_extension.so is committed to the repo.
# Run `make ext` only when you change Rust source in gp_extension/.
all: test-godot

setup:
	git submodule update --init --recursive

EXT_SRC := gp_extension/src
EXT_OUT := addons/gp_extension/bin/libgp_extension.so

ext: setup
	cargo build --release --manifest-path gp_extension/Cargo.toml
	mkdir -p addons/gp_extension/bin
	cp gp_extension/target/release/libgp_extension.so $(EXT_OUT)

test-rust:
	cargo test --manifest-path gp_extension/Cargo.toml

# Uses the pre-built .so from the repo; no Rust compile needed.
test-godot:
	godot --headless --path . -s res://tests/test_runner.gd 2>&1

clean:
	cargo clean --manifest-path gp_extension/Cargo.toml
	rm -f addons/gp_extension/bin/libgp_extension.so
