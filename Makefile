# go-guitar Makefile
# ──────────────────
# Targets:
#   make setup      — initialise git submodules (cycfi/q etc.)
#   make ext        — build the Rust GDExtension .so
#   make test-rust  — run Rust unit tests
#   make test-godot — run Godot headless tests (requires godot in PATH)
#   make all        — setup + ext

.PHONY: all setup ext test-rust test-godot clean

all: setup ext

# ── submodules ─────────────────────────────────────────────────────────────────
setup:
git submodule update --init --recursive

# ── Rust GDExtension ──────────────────────────────────────────────────────────
EXT_SRC := gp_extension/src
EXT_OUT := addons/gp_extension/bin/libgp_extension.so

ext: setup
cargo build --release --manifest-path gp_extension/Cargo.toml
mkdir -p addons/gp_extension/bin
cp gp_extension/target/release/libgp_extension.so $(EXT_OUT)

# ── tests ─────────────────────────────────────────────────────────────────────
test-rust:
cargo test --manifest-path gp_extension/Cargo.toml

test-godot: ext
godot --headless --path . -s res://tests/test_runner.gd 2>&1

# ── clean ─────────────────────────────────────────────────────────────────────
clean:
cargo clean --manifest-path gp_extension/Cargo.toml
rm -f addons/gp_extension/bin/libgp_extension.so
