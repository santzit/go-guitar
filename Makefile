.PHONY: all ext test-godot test-rust clean

GODOT ?= godot
GODOT_HEADLESS = $(GODOT) --headless

all: ext

ext:
	cd gp_extension && cargo build --release
	cp gp_extension/target/release/libgp_extension.so addons/gp_extension/bin/libgp_extension.linux.x86_64.so

test-rust:
	cd gp_extension && cargo test

test-godot:
	$(GODOT_HEADLESS) --path . -s res://tests/test_music_play.gd

clean:
	cd gp_extension && cargo clean
