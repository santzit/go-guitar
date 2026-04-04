# GoGuitar

A **Rocksmith-style guitar game** built with **Godot 4** that reads real
[Guitar Pro](https://www.guitar-pro.com/) tabs (`.gp` / `.gp3` / `.gp4` / `.gp5`).

Notes fall toward a perspective fretboard at the bottom of the screen —
press the matching keyboard key when they hit the line to score points.

---

## Features

- 6-string perspective highway (Rocksmith-inspired colour scheme)
- Real Guitar Pro file parsing via a Rust **GDExtension** backed by
  [`slundi/guitarpro`](https://github.com/slundi/guitarpro) (`scorelib`)
- Main menu → Song Select → Gameplay flow
- Score + combo tracking, per-string hit flash
- Fretboard strip at the bottom with active note indicators

---

## Requirements

| Tool | Version |
|------|---------|
| [Godot 4](https://godotengine.org/) | 4.1 or newer |
| [Rust + Cargo](https://rustup.rs/) | stable (1.75+) |
| [Git](https://git-scm.com/) | any |

---

## Building the GDExtension (required before running)

The GP file parser is a native Rust library.  Build it once before opening
the project in Godot:

```bash
# 1. Clone the repo
git clone https://github.com/santzit/go-guitar.git
cd go-guitar

# 2. Build the Rust extension
cd gp_extension
cargo build --release
cd ..

# 3. Copy the compiled library to where Godot expects it
mkdir -p addons/gp_extension/bin

# Linux
cp gp_extension/target/release/libgp_extension.so addons/gp_extension/bin/

# macOS
# cp gp_extension/target/release/libgp_extension.dylib addons/gp_extension/bin/

# Windows
# copy gp_extension\target\release\gp_extension.dll addons\gp_extension\bin\
```

---

## Adding Songs

Place Guitar Pro files in the `DLC/` directory:

```
DLC/
  smoke_on_the_water.gp5
  sweet_child_o_mine.gp4
  ...
```

The **Song Select** screen will list every `.gp` / `.gp3` / `.gp4` / `.gp5`
file it finds there.  See [`DLC/README.md`](DLC/README.md) for details.

---

## Playing

| Key | Action |
|-----|--------|
| `Z` | String 1 – low E |
| `X` | String 2 – A |
| `C` | String 3 – D |
| `V` | String 4 – G |
| `B` | String 5 – B |
| `N` | String 6 – high e |
| `ESC` | Back to main menu |

Press the key that matches the highlighted string **as the note reaches
the glowing hit line** at the bottom of the highway.

---

## Project Structure

```
go-guitar/
├── project.godot              # Godot 4 project file
├── gp_extension.gdextension   # GDExtension manifest
├── gp_extension/              # Rust GDExtension source
│   ├── Cargo.toml
│   └── src/lib.rs             # GpParser class (wraps scorelib)
├── addons/gp_extension/bin/   # Compiled native library (git-ignored)
├── scenes/
│   ├── main.tscn              # Main menu
│   ├── song_list.tscn         # Song selection
│   └── music_play.tscn        # Gameplay
├── scripts/
│   ├── game_state.gd          # Autoload singleton
│   ├── main.gd
│   ├── song_list.gd
│   └── music_play.gd          # Highway + note rendering + GP loading
└── DLC/                       # Drop your .gp files here
```

---

## Architecture

```
Godot (GDScript)          Rust GDExtension          scorelib (slundi/guitarpro)
─────────────────         ──────────────────         ──────────────────────────
FileAccess.open()   →     GpParser.parse_bytes()  →  Song::read_gp3/4/5()
PackedByteArray     →     Vec<u8>                 →  Track / Beat / Note structs
                   ←     Dictionary { notes }     ←  DURATION_QUARTER_TIME math
```

---

## License

MIT