extends Node2D

## ── Perspective highway constants ──────────────────────────────────────────
## The highway converges from a vanishing point at the top of the screen
## toward a "hit line" near the bottom, simulating a Rocksmith-style 3-D view.
const VANISH_X: float    = 640.0
const VANISH_Y: float    = 100.0
const HIT_Y: float       = 560.0
const HIGHWAY_HALF_W: float = 420.0  # half-width of the highway at the hit line

## ── Guitar string setup ─────────────────────────────────────────────────────
const NUM_STRINGS: int = 6
const STRING_NAMES: Array  = ["E", "A", "D", "G", "B", "e"]
## Rocksmith-inspired colours (low-E → high-e)
const STRING_COLORS: Array = [
	Color(0.90, 0.10, 0.10),   # E2  – Red
	Color(0.90, 0.85, 0.10),   # A2  – Yellow
	Color(0.15, 0.45, 0.95),   # D3  – Blue
	Color(0.95, 0.50, 0.10),   # G3  – Orange
	Color(0.15, 0.80, 0.20),   # B3  – Green
	Color(0.55, 0.10, 0.95),   # e4  – Purple
]

## Keyboard bindings for each string (Z X C V B N)
const STRING_KEYS: Array = [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N]

## ── Timing ──────────────────────────────────────────────────────────────────
## How many seconds of notes are visible at once in the highway
const LOOK_AHEAD: float  = 3.5
## Tolerance window for registering a hit
const HIT_WINDOW: float  = 0.18
## Extra seconds before song notes start (gives player time to get ready)
const START_DELAY: float = 3.0

## ── Fretboard (bottom) constants ────────────────────────────────────────────
const FRETBOARD_TOP: float    = 580.0
const FRETBOARD_HEIGHT: float = 140.0
const NUM_DISPLAY_FRETS: int  = 22
## Frets that get position-marker dots on a real guitar
const MARKER_FRETS: Array = [3, 5, 7, 9, 12, 15, 17, 19, 21]

## ── State ───────────────────────────────────────────────────────────────────
var song_data: Dictionary  = {}
var notes: Array           = []   # each element is a Dictionary from JSON + runtime flags
var current_time: float    = 0.0
var score: int             = 0
var combo: int             = 0
var message_text: String   = ""
var message_timer: float   = 0.0

## Hit-flash per string: how much alpha remains for the glow
var string_flash: Array    = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

@onready var score_label:      Label = $HUD/ScoreLabel
@onready var combo_label:      Label = $HUD/ComboLabel
@onready var song_title_label: Label = $HUD/SongTitleLabel
@onready var message_label:    Label = $HUD/MessageLabel
@onready var controls_label:   Label = $HUD/ControlsLabel

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	$HUD/BackButton.pressed.connect(_on_back_pressed)
	_load_song()

func _load_song() -> void:
	var path: String = GameState.current_song
	if path.is_empty() or not FileAccess.file_exists(path):
		path = "res://DLC/demo_song.json"

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_generate_demo_notes()
		return

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw) != OK:
		_generate_demo_notes()
		return

	song_data = json.get_data()
	notes     = song_data.get("notes", [])
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"])
	)
	song_title_label.text = song_data.get("title", path.get_file().get_basename())

func _generate_demo_notes() -> void:
	song_data = {"title": "Demo Riff", "artist": "GoGuitar", "bpm": 120}
	song_title_label.text = "Demo Riff"
	notes = []
	var t := 1.0
	# Simple ascending / descending scale across all strings
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
	# Second loop at higher frets
	t += len(pattern) * 0.5 + 1.0
	for i in range(len(pattern)):
		notes.append({
			"time":     t + i * 0.5,
			"string":   pattern[i][0],
			"fret":     pattern[i][1] + 2,
			"duration": 0.4,
		})

# ─────────────────────────────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	current_time += delta

	# Fade string flash indicators
	for i in range(NUM_STRINGS):
		if string_flash[i] > 0.0:
			string_flash[i] = maxf(0.0, string_flash[i] - delta * 4.0)

	# Fade message
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""

	# Update HUD labels
	score_label.text = "Score: %d" % score
	combo_label.text = "%dx" % combo if combo > 1 else ""

	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
## Drawing helpers
# ─────────────────────────────────────────────────────────────────────────────

## Return the screen X of lane `lane` at height `y`.
func _lane_x(lane: int, y: float) -> float:
	var progress: float = (y - VANISH_Y) / (HIT_Y - VANISH_Y)
	var left_x: float   = VANISH_X - HIGHWAY_HALF_W * progress
	var total_w: float  = HIGHWAY_HALF_W * 2.0 * progress
	return left_x + (lane + 0.5) * total_w / NUM_STRINGS

## Return the half-width of a lane at height `y`.
func _lane_half_w(y: float) -> float:
	var progress: float = (y - VANISH_Y) / (HIT_Y - VANISH_Y)
	return (HIGHWAY_HALF_W * 2.0 * progress) / NUM_STRINGS * 0.5

## Convert a note's beat time (in song seconds, before START_DELAY) to screen Y.
func _note_y(beat_time: float) -> float:
	var time_to_hit: float = (float(beat_time) + START_DELAY) - current_time
	return HIT_Y - (time_to_hit / LOOK_AHEAD) * (HIT_Y - VANISH_Y)

# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_highway()
	_draw_fret_lines()
	_draw_string_lanes()
	_draw_hit_zone()
	_draw_notes()
	_draw_fretboard()

func _draw_background() -> void:
	# Dark gradient background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.04, 0.09))

func _draw_highway() -> void:
	# Trapezoid highway background
	var pts := PackedVector2Array([
		Vector2(VANISH_X, VANISH_Y),
		Vector2(VANISH_X - HIGHWAY_HALF_W, HIT_Y),
		Vector2(VANISH_X + HIGHWAY_HALF_W, HIT_Y),
	])
	draw_colored_polygon(pts, Color(0.07, 0.07, 0.14))

	# Subtle grid horizontal lines (fret markers on highway)
	for fi in range(1, 13):
		var t: float = float(fi) / 12.0
		var y: float = VANISH_Y + t * (HIT_Y - VANISH_Y)
		var hw: float = HIGHWAY_HALF_W * t
		var alpha: float = 0.08 + t * 0.12
		draw_line(
			Vector2(VANISH_X - hw, y),
			Vector2(VANISH_X + hw, y),
			Color(0.4, 0.4, 0.5, alpha), 1.0
		)

func _draw_string_lanes() -> void:
	# Draw one coloured lane edge line per string boundary
	for i in range(NUM_STRINGS + 1):
		var frac: float = float(i) / NUM_STRINGS
		var x_hit: float = (VANISH_X - HIGHWAY_HALF_W) + frac * HIGHWAY_HALF_W * 2.0
		var col: Color
		if i < NUM_STRINGS:
			col = STRING_COLORS[i].darkened(0.55)
		else:
			col = Color(0.3, 0.3, 0.3, 0.5)
		draw_line(Vector2(VANISH_X, VANISH_Y), Vector2(x_hit, HIT_Y), col, 1.2)

func _draw_fret_lines() -> void:
	# Brighter horizontal markers at the "nut" + main fret positions
	pass  # already handled in _draw_highway grid

func _draw_hit_zone() -> void:
	for i in range(NUM_STRINGS):
		var cx: float  = _lane_x(i, HIT_Y)
		var hw: float  = _lane_half_w(HIT_Y) * 0.72
		var col: Color = STRING_COLORS[i]
		var flash: float = string_flash[i]

		# Outer glow (animated on hit)
		var glow_alpha: float = 0.25 + flash * 0.55
		draw_rect(
			Rect2(cx - hw - 5, HIT_Y - 7, hw * 2 + 10, 14),
			Color(col.r, col.g, col.b, glow_alpha)
		)
		# Inner pad
		draw_rect(
			Rect2(cx - hw, HIT_Y - 4, hw * 2, 8),
			Color(col.r, col.g, col.b, 0.85 + flash * 0.15)
		)

func _draw_notes() -> void:
	var font: Font = ThemeDB.fallback_font

	for note in notes:
		if note.get("hit", false):
			continue

		var beat_time: float = float(note["time"])
		var y: float         = _note_y(beat_time)

		# Skip notes outside the visible highway
		if y < VANISH_Y - 20.0 or y > HIT_Y + 80.0:
			# Mark as missed once it has scrolled past the hit zone
			if y > HIT_Y + 40.0 and not note.get("missed", false):
				note["missed"] = true
				combo           = 0
				GameState.combo = 0
			continue

		var s: int     = int(note["string"])
		var fret: int  = int(note.get("fret", 0))
		var col: Color = STRING_COLORS[s]

		var cx: float  = _lane_x(s, y)
		var hw: float  = _lane_half_w(y) * 0.78
		var nh: float  = maxf(7.0, hw * 0.55)

		# Drop shadow
		draw_rect(
			Rect2(cx - hw - 2, y - nh * 0.5 - 2, hw * 2 + 4, nh + 4),
			Color(0, 0, 0, 0.5)
		)
		# Note rectangle
		draw_rect(Rect2(cx - hw, y - nh * 0.5, hw * 2, nh), col)
		# Highlight stripe
		draw_rect(
			Rect2(cx - hw, y - nh * 0.5, hw * 2, nh * 0.35),
			Color(1, 1, 1, 0.22)
		)
		# Fret label (only when note is large enough to be legible)
		if hw >= 14.0 and fret > 0:
			var fret_str: String = str(fret)
			var fs: int = clamp(int(hw * 0.9), 11, 22)
			draw_string(
				font,
				Vector2(cx, y + fs * 0.35),
				fret_str,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1, fs,
				Color(0.05, 0.05, 0.05)
			)

func _draw_fretboard() -> void:
	var fb_top: float    = FRETBOARD_TOP
	var fb_w: float      = 1280.0
	var str_spacing: float = FRETBOARD_HEIGHT / (NUM_STRINGS + 1)
	var font: Font       = ThemeDB.fallback_font

	# Fretboard wood body
	draw_rect(Rect2(0, fb_top, fb_w, FRETBOARD_HEIGHT), Color(0.32, 0.22, 0.09))
	# Rosewood overlay
	draw_rect(Rect2(0, fb_top + 4, fb_w, FRETBOARD_HEIGHT - 8), Color(0.25, 0.16, 0.07))

	# Fret lines
	for f in range(NUM_DISPLAY_FRETS + 1):
		var fx: float       = float(f) / NUM_DISPLAY_FRETS * fb_w
		var is_nut: bool    = (f == 0)
		var thickness: float = 3.5 if is_nut else 1.2
		var col: Color       = Color(0.88, 0.88, 0.72) if is_nut else Color(0.60, 0.60, 0.60)
		draw_line(Vector2(fx, fb_top), Vector2(fx, fb_top + FRETBOARD_HEIGHT), col, thickness)

		# Fret number label below fretboard
		if f > 0 and f % 2 == 1:
			draw_string(
				font,
				Vector2(fx - float(NUM_DISPLAY_FRETS) / 2.0, fb_top + FRETBOARD_HEIGHT - 2),
				str(f),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 13,
				Color(0.75, 0.65, 0.30)
			)

	# Fret position markers (dots)
	for mf in MARKER_FRETS:
		if mf > NUM_DISPLAY_FRETS:
			continue
		var fx: float  = (float(mf) - 0.5) / NUM_DISPLAY_FRETS * fb_w
		var my: float  = fb_top + FRETBOARD_HEIGHT * 0.5
		var radius: float = 6.0 if mf == 12 else 4.5
		draw_circle(Vector2(fx, my), radius, Color(0.45, 0.35, 0.18))

	# Guitar strings
	for i in range(NUM_STRINGS):
		var sy: float         = fb_top + (i + 1) * str_spacing
		var thickness: float  = 3.8 - i * 0.45  # lower strings are thicker
		draw_line(Vector2(0, sy), Vector2(fb_w, sy), STRING_COLORS[i], thickness)

	# Active note indicators on the fretboard
	for note in notes:
		if note.get("hit", false) or note.get("missed", false):
			continue
		var time_to_hit: float = (float(note["time"]) + START_DELAY) - current_time
		if absf(time_to_hit) > HIT_WINDOW * 3.0:
			continue

		var si: int    = int(note["string"])
		var fret: int  = int(note.get("fret", 0))
		if fret <= 0 or fret > NUM_DISPLAY_FRETS:
			continue

		var fx: float = (float(fret) - 0.5) / NUM_DISPLAY_FRETS * fb_w
		var sy: float = fb_top + (si + 1) * str_spacing
		var col: Color = STRING_COLORS[si]
		# Glow ring
		draw_circle(Vector2(fx, sy), 13.0, Color(col.r, col.g, col.b, 0.30))
		# Solid dot
		draw_circle(Vector2(fx, sy), 9.0, col)
		# Fret label inside dot
		draw_string(
			font,
			Vector2(fx, sy + 5),
			str(fret),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1, 11,
			Color(0.05, 0.05, 0.05)
		)
