# GitHub Copilot Instructions — go-guitar

## Project Overview

A Rocksmith-style guitar game built with **Godot 4.4** (GDScript) and a **Rust GDExtension** (`gp_extension/`) that parses real Guitar Pro (`.gp`/`.gp3`/`.gp4`/`.gp5`) tab files via the [`scorelib`](https://github.com/slundi/guitarpro) library.

## Repository Layout

```
go-guitar/
├── DLC/                          # Guitar Pro song files (.gp5 etc.)
├── addons/gp_extension/bin/      # Compiled native library (libgp_extension.so/.dll/.dylib)
├── gp_extension/                 # Rust GDExtension source
│   ├── src/lib.rs                # GpParser Godot class + extract_notes logic
│   └── tests/gp_parser_tests.rs  # 21 Rust unit + integration tests
├── scenes/                       # Godot .tscn scene files
│   ├── main.tscn                 # Main menu
│   ├── song_list.tscn            # Song browser (scans DLC/)
│   └── music_play.tscn           # Gameplay highway scene
├── scripts/                      # GDScript files
│   ├── music_play.gd             # Highway rendering + input
│   ├── game_state.gd             # Autoload singleton (score, combo, current song)
│   ├── main.gd
│   └── song_list.gd
├── tests/
│   └── test_runner.gd            # 32 Godot headless tests
├── .godot/extension_list.cfg     # Required: tells Godot to load the GDExtension
├── Makefile                      # Build and test targets
└── gp_extension.gdextension      # GDExtension manifest
```

## Key Architecture Decisions

- **GDExtension at runtime**: GDScript never references `GpParser` directly at parse time. Always use `ClassDB.instantiate("GpParser")` so the script loads even when the extension is not compiled.
- **Note timing**: `beat.start` in scorelib is a *within-measure* tick offset (resets to `DURATION_QUARTER_TIME = 960` each measure). Absolute song time = `measure_tick_offset + (beat.start − 960)`, where `measure_tick_offset` is accumulated across measures using `MeasureHeader.time_signature`.
- **String mapping**: GP string numbering is 1-indexed (1 = high-e). Game string numbering is 0-indexed (0 = low-E). Conversion: `game_str = num_strings - gp_string`.
- **Fretboard XY layout**: Frets are columns (1–22, left→right), strings are rows (0=low-E top → 5=high-e bottom). Finger indicator dot position: X = `label_w + (fret − 0.5) / 22 × play_w`, Y = `fb_top + (string + 0.5) × row_h`.

## Build Commands

```bash
# Build the Rust GDExtension and install to addons/
make ext

# Run Rust unit + integration tests (no Godot needed)
make test-rust

# Run Godot headless scene tests (requires Godot 4.4 in PATH as 'godot')
make test-godot

# Run both
make test
```

## Testing Requirements

**Always run tests after every commit:**

```bash
make test-rust    # verifies: timing, string mapping, frets, duration math, end-to-end GP5 parse
make test-godot   # verifies: scene load, GpParser ClassDB, GameState autoload, 2841 notes at 110 BPM
```

Tests use the real file `DLC/the-ramones-baby_i_love_you_3.gp5` (2841 notes, 110 BPM, ~218 s).

Key regression test: `note_times_span_full_song_duration` asserts last note time > 180 s.

## Screenshots

After visual changes, generate 5 screenshots at different song positions using Godot's `--export-debug` or a headless rendering script and commit them to `docs/screenshots/`. Then upload and share in the PR reply so the reviewer can see the impact.

To take screenshots programmatically (requires Godot in PATH):

```bash
godot --headless --path . --script res://scripts/take_screenshots.gd
```

## Godot Scene Notes

- `GameState` is an autoload singleton — always check `get_root().has_node("GameState")` in tests, not `GameState` directly (autoloads are added after `_init()`; use `call_deferred("_run_tests")` in test scripts).
- `.godot/extension_list.cfg` **must** be committed — Godot uses it to discover GDExtension plugins in headless/CI mode.

## GDScript Style

- Use `const` for configuration values (timing windows, screen dimensions, colours).
- Use `@onready` for node references.
- Use `note.get("key", default)` (not `note["key"]`) when the key may be absent.
- All direct class-name references to GDExtension types must go through `ClassDB.instantiate("ClassName")`.

## Fretboard Rendering Rules

- **`fret = 0`** (open string) → glow the entire string row, no specific fret position.
- **`fret > 0`** (fretted note) → coloured dot at the exact `(fret, string)` intersection; dot radius must not exceed `row_h / 2` to stay within its row.
- Position marker dots: single dot at frets 1, 5, 7, 9, 15, 17, 19, 21; **double dots** at frets 3 and 12.
- String rows alternate background tints for visual clarity; fret numbers are shown below the grid.
