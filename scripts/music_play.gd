extends Node2D

## ── Perspective highway constants ────────────────────────────────────────────
## The highway converges from a vanishing point at the top of the screen toward
## a "hit line" near the bottom, giving a Rocksmith-style 3-D perspective feel.
const VANISH_X: float     = 640.0
const VANISH_Y: float     = 100.0
const HIT_Y: float        = 560.0
const HIGHWAY_HALF_W: float = 420.0   # half-width of highway at the hit line

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
const FRETBOARD_TOP: float    = 580.0
const FRETBOARD_HEIGHT: float = 140.0
const NUM_DISPLAY_FRETS: int  = 22
const MARKER_FRETS: Array     = [3, 5, 7, 9, 12, 15, 17, 19, 21]

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

## X coordinate of the centre of lane `lane` at screen height `y`.
func _lane_x(lane: int, y: float) -> float:
	var progress: float = (y - VANISH_Y) / (HIT_Y - VANISH_Y)
	var left_x: float   = VANISH_X - HIGHWAY_HALF_W * progress
	var total_w: float  = HIGHWAY_HALF_W * 2.0 * progress
	return left_x + (lane + 0.5) * total_w / NUM_STRINGS

## Half-width of a lane at screen height `y`.
func _lane_half_w(y: float) -> float:
	var progress: float = (y - VANISH_Y) / (HIT_Y - VANISH_Y)
	return (HIGHWAY_HALF_W * 2.0 * progress) / NUM_STRINGS * 0.5

## Convert a note's song-time (in seconds, before START_DELAY) to screen Y.
func _note_y(beat_time: float) -> float:
	var time_to_hit: float = (float(beat_time) + START_DELAY) - current_time
	return HIT_Y - (time_to_hit / LOOK_AHEAD) * (HIT_Y - VANISH_Y)

## Returns an Array[float] of size NUM_STRINGS: the nearest time-to-hit (s) for
## an active note on each string within the look-ahead window, INF when none.
func _build_nearest_times() -> Array:
	var nearest: Array = [INF, INF, INF, INF, INF, INF]
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
	# Very dark near-black navy background — Rocksmith style
	draw_colored_polygon(PackedVector2Array([
		Vector2(VANISH_X, VANISH_Y),
		Vector2(VANISH_X - HIGHWAY_HALF_W, HIT_Y),
		Vector2(VANISH_X + HIGHWAY_HALF_W, HIT_Y),
	]), Color(0.02, 0.03, 0.08))

	# White horizontal fret grid lines receding into the distance
	for fi in range(1, 13):
		var t: float     = float(fi) / 12.0
		var y: float     = VANISH_Y + t * (HIT_Y - VANISH_Y)
		var hw: float    = HIGHWAY_HALF_W * t
		var alpha: float = 0.08 + t * 0.16
		draw_line(
			Vector2(VANISH_X - hw, y),
			Vector2(VANISH_X + hw, y),
			Color(0.70, 0.80, 1.00, alpha), 1.0
		)

func _draw_string_lanes() -> void:
	# Thin white/light-blue lane separator lines between strings (very subtle)
	for i in range(NUM_STRINGS + 1):
		var frac: float  = float(i) / NUM_STRINGS
		var x_hit: float = (VANISH_X - HIGHWAY_HALF_W) + frac * HIGHWAY_HALF_W * 2.0
		draw_line(Vector2(VANISH_X, VANISH_Y), Vector2(x_hit, HIT_Y),
			Color(0.55, 0.70, 0.95, 0.28), 0.8)

	# Bright glowing colored string lines at the centre of each lane — Rocksmith style.
	# Each string is drawn twice: a wide semi-transparent outer glow + a thin bright core.
	for i in range(NUM_STRINGS):
		var x_hit: float = _lane_x(i, HIT_Y)
		var col: Color   = STRING_COLORS[i]
		# Outer glow
		draw_line(Vector2(VANISH_X, VANISH_Y), Vector2(x_hit, HIT_Y),
			Color(col.r, col.g, col.b, 0.22), 4.5)
		# Bright core
		draw_line(Vector2(VANISH_X, VANISH_Y), Vector2(x_hit, HIT_Y),
			Color(col.r, col.g, col.b, 0.90), 1.5)

func _draw_hit_zone(nearest: Array) -> void:
	for i in range(NUM_STRINGS):
		var cx: float    = _lane_x(i, HIT_Y)
		var hw: float    = _lane_half_w(HIT_Y) * 0.72
		var col: Color   = STRING_COLORS[i]
		var flash: float = string_flash[i]

		# Proximity glow: ramps from 0 at 2 s out to full at the hit line.
		var tth: float  = nearest[i]
		var prox: float = 0.0
		if tth < INF:
			prox = clamp(1.0 - tth / 2.0, 0.0, 1.0)

		# Outer glow (brightens on key press AND as note approaches)
		draw_rect(
			Rect2(cx - hw - 5, HIT_Y - 7, hw * 2 + 10, 14),
			Color(col.r, col.g, col.b, 0.25 + flash * 0.55 + prox * 0.35)
		)
		# Solid inner pad
		draw_rect(
			Rect2(cx - hw, HIT_Y - 4, hw * 2, 8),
			Color(col.r, col.g, col.b, 0.85 + flash * 0.15)
		)

func _draw_notes() -> void:
	var font: Font = ThemeDB.fallback_font

	for note in notes:
		if note.get("hit", false):
			continue

		var y: float    = _note_y(float(note["time"]))
		var s: int      = int(note["string"])
		var fret: int   = int(note.get("fret", 0))

		# Visible range: slightly above the vanishing point to just below the hit line
		if y < VANISH_Y - 20.0 or y > HIT_Y + 80.0:
			if y > HIT_Y + 40.0 and not note.get("missed", false):
				note["missed"] = true
				combo           = 0
				GameState.combo = 0
			continue

		var col: Color = STRING_COLORS[s]
		var cx: float  = _lane_x(s, y)
		var hw: float  = _lane_half_w(y) * 0.78
		var nh: float  = maxf(7.0, hw * 0.55)

		# Drop shadow
		draw_rect(
			Rect2(cx - hw - 2, y - nh * 0.5 - 2, hw * 2 + 4, nh + 4),
			Color(0, 0, 0, 0.5)
		)
		# Note body
		draw_rect(Rect2(cx - hw, y - nh * 0.5, hw * 2, nh), col)
		# Highlight streak
		draw_rect(
			Rect2(cx - hw, y - nh * 0.5, hw * 2, nh * 0.35),
			Color(1, 1, 1, 0.22)
		)
		# Fret number (drawn when the note is large enough to be legible)
		if hw >= 14.0 and fret > 0:
			var fs: int = clamp(int(hw * 0.9), 11, 22)
			draw_string(
				font,
				Vector2(cx, y + fs * 0.35),
				str(fret),
				HORIZONTAL_ALIGNMENT_CENTER,
				-1, fs,
				Color(0.05, 0.05, 0.05)
			)

func _draw_fretboard(nearest: Array) -> void:
	var fb_top: float  = FRETBOARD_TOP
	var fb_w: float    = 1280.0
	var str_sp: float  = FRETBOARD_HEIGHT / (NUM_STRINGS + 1)
	var font: Font     = ThemeDB.fallback_font

	# Fretboard body
	draw_rect(Rect2(0, fb_top, fb_w, FRETBOARD_HEIGHT), Color(0.32, 0.22, 0.09))
	draw_rect(Rect2(0, fb_top + 4, fb_w, FRETBOARD_HEIGHT - 8), Color(0.25, 0.16, 0.07))

	# Fret lines + labels
	for f in range(NUM_DISPLAY_FRETS + 1):
		var fx: float        = float(f) / NUM_DISPLAY_FRETS * fb_w
		var is_nut: bool     = (f == 0)
		var thickness: float = 3.5 if is_nut else 1.2
		var col: Color       = Color(0.88, 0.88, 0.72) if is_nut else Color(0.60, 0.60, 0.60)
		draw_line(Vector2(fx, fb_top), Vector2(fx, fb_top + FRETBOARD_HEIGHT), col, thickness)
		if f > 0 and f % 2 == 1:
			draw_string(
				font,
				Vector2(fx - 5, fb_top + FRETBOARD_HEIGHT - 3),
				str(f),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 13,
				Color(0.75, 0.65, 0.30)
			)

	# Position dots
	for mf in MARKER_FRETS:
		if mf > NUM_DISPLAY_FRETS:
			continue
		var fx: float    = (float(mf) - 0.5) / NUM_DISPLAY_FRETS * fb_w
		var my: float    = fb_top + FRETBOARD_HEIGHT * 0.5
		var r: float     = 6.0 if mf == 12 else 4.5
		draw_circle(Vector2(fx, my), r, Color(0.45, 0.35, 0.18))

	# Guitar strings — brighten for strings that have an incoming note.
	for i in range(NUM_STRINGS):
		var sy: float        = fb_top + (i + 1) * str_sp
		var thickness: float = 3.8 - i * 0.45
		var tth: float       = nearest[i]
		var col: Color
		if tth < INF:
			var t: float = clamp(1.0 - tth / LOOK_AHEAD, 0.0, 1.0)
			col = STRING_COLORS[i].lightened(t * 0.45)
		else:
			col = STRING_COLORS[i].darkened(0.30)
		draw_line(Vector2(0, sy), Vector2(fb_w, sy), col, thickness)

	# String-name labels on the left edge (E A D G B e)
	for i in range(NUM_STRINGS):
		var sy: float  = fb_top + (i + 1) * str_sp
		var col: Color = STRING_COLORS[i] if nearest[i] < INF else STRING_COLORS[i].darkened(0.35)
		draw_string(
			font,
			Vector2(4, sy + 5),
			STRING_NAMES[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13,
			col
		)

	# Finger-position indicators — shown for notes within FINGER_PREVIEW seconds.
	# Dots grow in size and opacity as the note approaches (prepare → play).
	for note in notes:
		if note.get("hit", false) or note.get("missed", false):
			continue
		var tth: float = (float(note["time"]) + START_DELAY) - current_time
		if tth < -HIT_WINDOW or tth > FINGER_PREVIEW:
			continue

		var si: int   = int(note["string"])
		var fret: int = int(note.get("fret", 0))
		if fret <= 0 or fret > NUM_DISPLAY_FRETS:
			continue

		# prox: 0.0 = FINGER_PREVIEW seconds away, 1.0 = at hit line
		var prox: float = clamp(1.0 - tth / FINGER_PREVIEW, 0.0, 1.0)
		var col: Color  = STRING_COLORS[si]
		var fx: float   = (float(fret) - 0.5) / NUM_DISPLAY_FRETS * fb_w
		var sy: float   = fb_top + (si + 1) * str_sp

		# Outer halo (dim/small when far; grows with proximity)
		var halo_r: float = lerp(5.0, 14.0, prox)
		draw_circle(Vector2(fx, sy), halo_r + 3.0,
			Color(col.r, col.g, col.b, 0.15 + prox * 0.20))
		# Filled dot
		draw_circle(Vector2(fx, sy), halo_r,
			Color(col.r, col.g, col.b, 0.55 + prox * 0.45))
		# Fret number — always readable
		var fs: int = clamp(int(lerp(9.0, 12.0, prox)), 9, 12)
		draw_string(
			font,
			Vector2(fx, sy + fs * 0.45),
			str(fret),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1, fs,
			Color(0.05, 0.05, 0.05)
		)
