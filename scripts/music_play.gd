extends Node2D

## ── Scrolling tab highway constants ─────────────────────────────────────────
## The highway is a 2D scrolling-tab view (no 3D perspective):
##   Y axis = string row  (index 0 = low-E at top … index 5 = high-e at bottom)
##   X axis = time        (hit zone on left; future notes scroll in from right)
## Notes at the same beat time stack vertically in their string rows.
const HIT_X: float    = 80.0    # X of the vertical hit zone line
const HW_TOP: float   = 75.0    # Top of the highway (below HUD title / score)

## ── Guitar string setup ──────────────────────────────────────────────────────
const NUM_STRINGS: int = 6
const STRING_NAMES: Array  = ["E", "A", "D", "G", "B", "e"]
## Rocksmith-inspired colours, index 0 = low-E, index 5 = high-e
const STRING_COLORS: Array = [
	Color(0.90, 0.10, 0.10),   # E2 – Red
	Color(0.90, 0.85, 0.10),   # A2 – Yellow
	Color(0.15, 0.45, 0.95),   # D3 – Blue
	Color(0.95, 0.50, 0.10),   # G3 – Orange
	Color(0.15, 0.80, 0.20),   # B3 – Green
	Color(0.55, 0.10, 0.95),   # e4 – Purple
]
## Keyboard mapping: Z=string0 (low-E) … N=string5 (high-e)
const STRING_KEYS: Array = [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N]

## ── Timing ───────────────────────────────────────────────────────────────────
const LOOK_AHEAD: float      = 3.5    # seconds of notes visible ahead of hit line
const HIT_WINDOW: float      = 0.18   # seconds tolerance for registering a hit
const START_DELAY: float     = 3.0    # lead-in before first note
const FINGER_PREVIEW: float  = 2.0    # seconds ahead where fretboard finger guides appear

## ── Fretboard (bottom strip) ─────────────────────────────────────────────────
const FRETBOARD_TOP: float    = 575.0
const FRETBOARD_HEIGHT: float = 145.0
const NUM_DISPLAY_FRETS: int  = 22
## Frets with a single position marker dot
const MARKER_FRETS: Array     = [1, 3, 5, 7, 9, 12, 15, 17, 19, 21]
## Frets with double position marker dots (octave/landmark frets)
const DOUBLE_DOT_FRETS: Array = [3, 12]

## ── Runtime state ────────────────────────────────────────────────────────────
var song_data: Dictionary = {}
var notes: Array          = []
var current_time: float   = 0.0
var score: int            = 0
var combo: int            = 0
var message_text: String  = ""
var message_timer: float  = 0.0
var string_flash: Array   = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

@onready var score_label:      Label = $HUD/ScoreLabel
@onready var combo_label:      Label = $HUD/ComboLabel
@onready var song_title_label: Label = $HUD/SongTitleLabel
@onready var message_label:    Label = $HUD/MessageLabel

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	$HUD/BackButton.pressed.connect(_on_back_pressed)
	_load_song()

# ── Song loading ──────────────────────────────────────────────────────────────

func _load_song() -> void:
	var path: String = GameState.current_song
	if path.is_empty():
		_generate_demo_notes()
		return

	var ext: String = path.get_extension().to_lower()
	if ext in ["gp", "gp3", "gp4", "gp5"]:
		_load_gp_file(path)
	else:
		push_warning("Unsupported file type '%s'. Using demo notes." % ext)
		_generate_demo_notes()

func _load_gp_file(path: String) -> void:
	## Read file bytes with Godot's FileAccess (handles res://, user://, and
	## packed .pck exports transparently), then hand the raw bytes to the
	## GpParser GDExtension which uses scorelib to do the actual parsing.

	# Graceful fallback when the GDExtension has not been compiled yet.
	if not ClassDB.class_exists("GpParser"):
		push_warning(
			"GpParser GDExtension not found. Build it first:\n" +
			"  cd gp_extension && cargo build --release\n" +
			"  (see README for full instructions)\n" +
			"Falling back to demo mode."
		)
		_generate_demo_notes()
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open '%s': %s" % [path, FileAccess.get_open_error()])
		_generate_demo_notes()
		return

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var ext: String = path.get_extension().to_lower()
	var parser      = ClassDB.instantiate("GpParser") # resolved at runtime via GDExtension
	var data: Dictionary = parser.parse_bytes(bytes, ext)

	if data.is_empty():
		push_error("GpParser returned empty data for '%s'." % path)
		_generate_demo_notes()
		return

	song_data = data
	notes     = data.get("notes", [])
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"])
	)
	song_title_label.text = data.get("title", path.get_file().get_basename())

func _generate_demo_notes() -> void:
	## Fallback content shown when no GP file is loaded or parsing fails.
	song_data = {"title": "Demo Riff (no GP file loaded)", "bpm": 120}
	song_title_label.text = song_data["title"]
	notes = []
	var t := 1.0
	# Simple ascending/descending scale across all 6 strings
	var pattern: Array = [
		[0, 5], [1, 7], [2, 5], [3, 7], [4, 5], [5, 8],
		[4, 5], [3, 7], [2, 5], [1, 7], [0, 5], [0, 7],
	]
	for i in range(len(pattern)):
		notes.append({
			"time":     t + i * 0.5,
			"string":   pattern[i][0],
			"fret":     pattern[i][1],
			"duration": 0.4,
		})

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for i in range(NUM_STRINGS):
			if event.physical_keycode == STRING_KEYS[i]:
				_check_hit(i)
				return
		if event.physical_keycode == KEY_ESCAPE:
			_on_back_pressed()

func _check_hit(string_index: int) -> void:
	string_flash[string_index] = 1.0

	var best_note: Dictionary = {}
	var best_diff: float      = HIT_WINDOW + 0.01

	for note in notes:
		if note.get("hit", false) or note.get("missed", false):
			continue
		var note_time: float = float(note["time"]) + START_DELAY
		var diff: float      = absf(note_time - current_time)
		if int(note["string"]) == string_index and diff < best_diff:
			best_diff = diff
			best_note = note

	if not best_note.is_empty():
		best_note["hit"] = true
		combo            += 1
		var pts: int      = 100 * combo
		score            += pts
		GameState.score   = score
		GameState.combo   = combo
		_show_message("GREAT! +%d" % pts)
	else:
		combo           = 0
		GameState.combo = 0
		_show_message("MISS")

func _show_message(msg: String) -> void:
	message_label.text = msg
	message_timer      = 0.8

func _on_back_pressed() -> void:
	GameState.update_high_score(GameState.current_song, score)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ── Frame update ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	current_time += delta

	for i in range(NUM_STRINGS):
		if string_flash[i] > 0.0:
			string_flash[i] = maxf(0.0, string_flash[i] - delta * 4.0)

	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""

	score_label.text = "Score: %d" % score
	combo_label.text = "%dx" % combo if combo > 1 else ""

	queue_redraw()

# ── Drawing helpers ───────────────────────────────────────────────────────────

## X screen coordinate for a note whose time-to-hit is `tth` seconds.
## tth = 0          → HIT_X  (at the hit zone)
## tth = LOOK_AHEAD → 1280.0 (right edge, about to enter view)
func _note_x(tth: float) -> float:
	return HIT_X + (tth / LOOK_AHEAD) * (1280.0 - HIT_X)

## Y screen centre of highway string row `s` (0 = low-E at top, 5 = high-e at bottom).
func _string_row_y(s: int) -> float:
	var row_h: float = (FRETBOARD_TOP - HW_TOP) / NUM_STRINGS
	return HW_TOP + (s + 0.5) * row_h

## Returns an Array[float] of size NUM_STRINGS: the nearest time-to-hit (s) for
## an active note on each string within the look-ahead window, INF when none.
func _build_nearest_times() -> Array:
	var nearest: Array = []
	nearest.resize(NUM_STRINGS)
	nearest.fill(INF)
	for note in notes:
		if note.get("hit", false) or note.get("missed", false):
			continue
		var si: int    = int(note["string"])
		var tth: float = (float(note["time"]) + START_DELAY) - current_time
		if tth < -HIT_WINDOW or tth >= LOOK_AHEAD:
			continue
		if tth < nearest[si]:
			nearest[si] = tth
	return nearest

# ── _draw ─────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var nearest: Array = _build_nearest_times()
	_draw_background()
	_draw_highway()
	_draw_string_lanes()
	_draw_hit_zone(nearest)
	_draw_notes()
	_draw_fretboard(nearest)

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.03, 0.07))

func _draw_highway() -> void:
	var hw_h: float = FRETBOARD_TOP - HW_TOP
	# Dark near-black background for the whole highway area
	draw_rect(Rect2(0.0, HW_TOP, 1280.0, hw_h), Color(0.02, 0.03, 0.08))
	# Faint vertical time-grid lines (every 0.5 s of look-ahead)
	var step: float = 0.5
	var t: float    = step
	while t < LOOK_AHEAD:
		var lx: float = _note_x(t)
		draw_line(Vector2(lx, HW_TOP), Vector2(lx, FRETBOARD_TOP),
			Color(0.25, 0.32, 0.55, 0.18), 1.0)
		t += step

func _draw_string_lanes() -> void:
	var row_h: float = (FRETBOARD_TOP - HW_TOP) / NUM_STRINGS
	var font: Font   = ThemeDB.fallback_font
	for i in range(NUM_STRINGS):
		var ry: float  = HW_TOP + i * row_h
		var sy: float  = ry + row_h * 0.5
		# Alternating row tints (note play-area only, right of hit zone)
		var bg: Color  = Color(0.04, 0.05, 0.11) if (i % 2 == 0) else Color(0.02, 0.03, 0.07)
		draw_rect(Rect2(HIT_X, ry, 1280.0 - HIT_X, row_h), bg)
		# Row divider
		if i > 0:
			draw_line(Vector2(0.0, ry), Vector2(1280.0, ry),
				Color(0.20, 0.28, 0.48, 0.45), 1.0)
		# String name label to the left of the hit zone
		draw_string(font, Vector2(4.0, sy + 5.0), STRING_NAMES[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, STRING_COLORS[i])
	# Bottom border of highway
	draw_line(Vector2(0.0, FRETBOARD_TOP), Vector2(1280.0, FRETBOARD_TOP),
		Color(0.30, 0.42, 0.65, 0.60), 2.0)

func _draw_hit_zone(nearest: Array) -> void:
	var row_h: float  = (FRETBOARD_TOP - HW_TOP) / NUM_STRINGS
	var r_base: float = row_h * 0.28
	# Vertical glowing hit line
	draw_line(Vector2(HIT_X, HW_TOP), Vector2(HIT_X, FRETBOARD_TOP),
		Color(0.70, 0.82, 1.00, 0.80), 2.0)
	for i in range(NUM_STRINGS):
		var sy: float    = _string_row_y(i)
		var col: Color   = STRING_COLORS[i]
		var flash: float = string_flash[i]
		var tth: float   = nearest[i]
		var prox: float  = 0.0
		if tth < INF:
			prox = clamp(1.0 - tth / FINGER_PREVIEW, 0.0, 1.0)
		# Outer glow (brightens when a note is near or a key is pressed)
		draw_circle(Vector2(HIT_X, sy), r_base + 5.0,
			Color(col.r, col.g, col.b, 0.18 + flash * 0.40 + prox * 0.28))
		# Solid indicator circle
		draw_circle(Vector2(HIT_X, sy), r_base,
			Color(col.r, col.g, col.b, 0.72 + flash * 0.28))

func _draw_notes() -> void:
	var font: Font    = ThemeDB.fallback_font
	var row_h: float  = (FRETBOARD_TOP - HW_TOP) / NUM_STRINGS
	var note_r: float = row_h * 0.30   # note circle radius

	for note in notes:
		if note.get("hit", false):
			continue

		var s: int     = int(note["string"])
		var fret: int  = int(note.get("fret", 0))
		var tth: float = (float(note["time"]) + START_DELAY) - current_time

		# Skip notes outside the visible window; mark overdue ones as missed.
		if tth < -HIT_WINDOW or tth >= LOOK_AHEAD:
			if tth < -HIT_WINDOW and not note.get("missed", false):
				note["missed"] = true
				combo           = 0
				GameState.combo = 0
			continue

		var nx: float  = _note_x(tth)
		var sy: float  = _string_row_y(s)
		var col: Color = STRING_COLORS[s]

		if fret == 0:
			# Open string: outlined circle (ring) to distinguish from fretted notes
			draw_arc(Vector2(nx, sy), note_r + 2.0, 0.0, TAU, 32,
				Color(col.r, col.g, col.b, 0.30), 4.0)
			draw_arc(Vector2(nx, sy), note_r, 0.0, TAU, 32, col, 2.5)
			# "0" label
			var fs: int = clamp(int(note_r * 0.88), 9, 15)
			draw_string(font, Vector2(nx, sy + fs * 0.38), "0",
				HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
		else:
			# Fretted note: filled circle + fret label
			# Outer glow halo
			draw_circle(Vector2(nx, sy), note_r + 3.0,
				Color(col.r, col.g, col.b, 0.22))
			# Filled body
			draw_circle(Vector2(nx, sy), note_r, col)
			# Bright highlight spot
			draw_circle(Vector2(nx, sy - note_r * 0.28), note_r * 0.38,
				Color(1.0, 1.0, 1.0, 0.30))
			# Fret number label
			if note_r >= 8.0:
				var fs: int = clamp(int(note_r * 0.88), 9, 15)
				draw_string(font, Vector2(nx, sy + fs * 0.38), str(fret),
					HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0.05, 0.05, 0.05))

func _draw_fretboard(nearest: Array) -> void:
	var fb_top: float  = FRETBOARD_TOP
	var fb_w: float    = 1280.0
	# Reserve left edge for string-name labels and right margin
	var label_w: float = 22.0
	var play_w: float  = fb_w - label_w
	# Each string occupies an equal row; leave a top/bottom margin
	var row_h: float   = FRETBOARD_HEIGHT / float(NUM_STRINGS)
	var font: Font     = ThemeDB.fallback_font

	# ── Fretboard body ──────────────────────────────────────────────────────
	draw_rect(Rect2(0, fb_top, fb_w, FRETBOARD_HEIGHT), Color(0.28, 0.18, 0.07))
	# Alternating row tints so each string lane is visually distinct
	for i in range(NUM_STRINGS):
		var ry: float = fb_top + i * row_h
		var tint: Color = Color(0.32, 0.22, 0.09, 0.8) if (i % 2 == 0) else Color(0.22, 0.14, 0.05, 0.8)
		draw_rect(Rect2(label_w, ry, play_w, row_h), tint)

	# ── Fret wire lines + slot labels ───────────────────────────────────────
	for f in range(NUM_DISPLAY_FRETS + 1):
		var fx: float        = label_w + float(f) / NUM_DISPLAY_FRETS * play_w
		var is_nut: bool     = (f == 0)
		var thickness: float = 3.5 if is_nut else 1.0
		var col: Color       = Color(0.90, 0.88, 0.70) if is_nut else Color(0.55, 0.55, 0.50)
		draw_line(Vector2(fx, fb_top), Vector2(fx, fb_top + FRETBOARD_HEIGHT), col, thickness)
		if f > 0:
			# Fret number label centered in each slot (between wire f-1 and wire f)
			var slot_cx: float = label_w + (float(f) - 0.5) / NUM_DISPLAY_FRETS * play_w
			draw_string(
				font,
				Vector2(slot_cx, fb_top + FRETBOARD_HEIGHT - 2),
				str(f),
				HORIZONTAL_ALIGNMENT_CENTER,
				-1, 9,
				Color(0.70, 0.60, 0.28)
			)

	# ── Position marker dots ─────────────────────────────────────────────────
	# Dots sit between the middle string rows (visually between rows 2 and 3).
	for mf in MARKER_FRETS:
		if mf > NUM_DISPLAY_FRETS:
			continue
		var slot_cx: float = label_w + (float(mf) - 0.5) / NUM_DISPLAY_FRETS * play_w
		var dot_col: Color = Color(0.50, 0.40, 0.20)
		if mf in DOUBLE_DOT_FRETS:
			# Double dot: placed at 1/3 and 2/3 of the fretboard height
			var y1: float = fb_top + FRETBOARD_HEIGHT * 0.28
			var y2: float = fb_top + FRETBOARD_HEIGHT * 0.72
			draw_circle(Vector2(slot_cx, y1), 4.5, dot_col)
			draw_circle(Vector2(slot_cx, y2), 4.5, dot_col)
		else:
			# Single dot: centred between middle two strings
			var my: float = fb_top + FRETBOARD_HEIGHT * 0.50
			draw_circle(Vector2(slot_cx, my), 4.0, dot_col)

	# ── Guitar strings (horizontal lines) ───────────────────────────────────
	# Each string is drawn through the vertical centre of its row.
	# Row i → centre Y = fb_top + (i + 0.5) * row_h
	for i in range(NUM_STRINGS):
		var sy: float        = fb_top + (i + 0.5) * row_h
		var thickness: float = 3.8 - i * 0.45
		var tth: float       = nearest[i]
		var col: Color
		if tth < INF:
			var t: float = clamp(1.0 - tth / LOOK_AHEAD, 0.0, 1.0)
			col = STRING_COLORS[i].lightened(t * 0.45)
		else:
			col = STRING_COLORS[i].darkened(0.35)
		draw_line(Vector2(label_w, sy), Vector2(fb_w, sy), col, thickness)

	# ── String-name labels on the left edge (E A D G B e) ───────────────────
	for i in range(NUM_STRINGS):
		var sy: float  = fb_top + (i + 0.5) * row_h
		var col: Color = STRING_COLORS[i] if nearest[i] < INF else STRING_COLORS[i].darkened(0.40)
		draw_string(
			font,
			Vector2(2, sy + 5),
			STRING_NAMES[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13,
			col
		)

	# ── Finger-position indicators ───────────────────────────────────────────
	# Show ONE indicator per string — the nearest upcoming note only.
	# Multiple dots per row (e.g. fret-1 and fret-2 side-by-side) are confusing;
	# one dot per row stacks them cleanly in the fretboard grid.
	# XY: X = slot centre for the fret, Y = row centre for the string.
	# Max dot radius capped so dots stay within their row.
	var max_r: float = row_h * 0.42  # fits inside each string row

	# Build nearest upcoming note per string within FINGER_PREVIEW.
	var nearest_note: Array = []
	nearest_note.resize(NUM_STRINGS)
	for i in range(NUM_STRINGS):
		nearest_note[i] = null
	for note in notes:
		if note.get("hit", false) or note.get("missed", false):
			continue
		var tth: float = (float(note["time"]) + START_DELAY) - current_time
		if tth < -HIT_WINDOW or tth > FINGER_PREVIEW:
			continue
		var si: int = int(note["string"])
		if nearest_note[si] == null:
			nearest_note[si] = note
		else:
			var existing_tth: float = (float(nearest_note[si]["time"]) + START_DELAY) - current_time
			if tth < existing_tth:
				nearest_note[si] = note

	# Draw one indicator per string (fretted notes only; open strings have no
	# fret to highlight so they are indicated on the highway instead).
	for i in range(NUM_STRINGS):
		var note = nearest_note[i]
		if note == null:
			continue
		var tth: float  = (float(note["time"]) + START_DELAY) - current_time
		var si: int     = int(note["string"])
		var fret: int   = int(note.get("fret", 0))
		if fret == 0:
			continue   # open string — no fretboard dot needed
		var prox: float = clamp(1.0 - tth / FINGER_PREVIEW, 0.0, 1.0)
		var col: Color  = STRING_COLORS[si]
		var sy: float   = fb_top + (si + 0.5) * row_h
		# Fretted note: dot at the exact fret × string intersection.
		if fret > NUM_DISPLAY_FRETS:
			continue
		var fx: float = label_w + (float(fret) - 0.5) / NUM_DISPLAY_FRETS * play_w
		var r: float  = lerp(max_r * 0.45, max_r, prox)
		# Outer halo
		draw_circle(Vector2(fx, sy), r + 2.0,
			Color(col.r, col.g, col.b, 0.20 + prox * 0.25))
		# Filled dot
		draw_circle(Vector2(fx, sy), r,
			Color(col.r, col.g, col.b, 0.65 + prox * 0.35))
		# Fret number inside the dot (only when large enough)
		if r >= 6.0:
			var fs: int = clamp(int(r * 1.1), 8, 12)
			draw_string(font, Vector2(fx, sy + fs * 0.38), str(fret),
				HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0.05, 0.05, 0.05))
