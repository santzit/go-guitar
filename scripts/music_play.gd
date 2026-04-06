class_name MusicPlay
extends Node2D

# ── constants ──────────────────────────────────────────────────────────────────
const NUM_STRINGS    := 6
const TICKS_PER_BEAT := 960
const BPM_DEFAULT    := 120.0
const LOOKAHEAD_SECS := 4.0

# Perspective camera constants (simulate Rocksmith 3D highway)
const VP             := Vector2(640.0, 120.0)  # vanishing point (top center)
const HIT_Y          := 545.0                  # y of hit zone (near player)
const HIGHWAY_LEFT   := 60.0                   # left edge at hit zone
const HIGHWAY_RIGHT_X := 1220.0               # right edge at hit zone
const FRETBOARD_Y    := 558.0                  # top of fretboard strip
const FRETBOARD_H    := 135.0                  # height of fretboard strip
const NUM_FRETS      := 24
const VIEWPORT_W     := 1280.0
const VIEWPORT_H     := 720.0

# String colors: E2=red, A=yellow, D=blue, G=orange, B=green, e5=purple
const STRING_COLORS := [
	Color(1.0, 0.2, 0.2),
	Color(1.0, 0.9, 0.1),
	Color(0.2, 0.5, 1.0),
	Color(1.0, 0.5, 0.1),
	Color(0.2, 0.9, 0.2),
	Color(0.8, 0.2, 1.0),
]

const DOUBLE_DOT_FRETS := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]

var notes: Array = []
var current_tick: float = 0.0
var ticks_per_sec: float = 0.0
var song_path: String = ""
static var current_song_path: String = ""

func _ready() -> void:
	song_path = current_song_path
	if song_path != "":
		_load_song(song_path)
	else:
		_load_demo_notes()
	ticks_per_sec = (BPM_DEFAULT / 60.0) * TICKS_PER_BEAT

func _load_demo_notes() -> void:
	var patterns = [
		[0, 0], [1, 2], [2, 2], [3, 2],
		[0, 0], [1, 2], [2, 2], [3, 2],
		[0, 5], [1, 5], [2, 5],
		[0, 7], [1, 7], [2, 7],
		[3, 9], [4, 9], [5, 9],
		[5, 12], [4, 10], [3, 9], [2, 7], [1, 5], [0, 3],
	]
	var t = 0
	var dur = 480
	for rep in 8:
		for p in patterns:
			notes.append({"string": p[0], "fret": p[1], "tick": t, "duration_ticks": dur})
			t += dur
	notes.sort_custom(func(a, b): return a.tick < b.tick)

func _load_song(path: String) -> void:
	var PsarcParserClass = preload("res://scripts/psarc_parser.gd")
	var parser = PsarcParserClass.new()
	var song_data = parser.parse(path)
	if song_data.is_empty():
		_load_demo_notes()
		return
	notes = song_data.get("notes", [])
	var bpm = song_data.get("bpm", BPM_DEFAULT)
	ticks_per_sec = (bpm / 60.0) * TICKS_PER_BEAT

func _process(delta: float) -> void:
	current_tick += delta * ticks_per_sec
	queue_redraw()

# ── perspective helpers ────────────────────────────────────────────────────────

## Returns depth in [0.0, 1.0]: 0 = at player (hit zone), 1 = far (VP)
func _depth_for_tick(note_tick: float) -> float:
	var secs_ahead = (note_tick - current_tick) / max(ticks_per_sec, 1.0)
	return clamp(secs_ahead / LOOKAHEAD_SECS, 0.0, 1.0)

## Returns string fraction [0.0=left/E2 .. 1.0=right/e5]
func _string_frac(si: int) -> float:
	return (si + 0.5) / float(NUM_STRINGS)

## Project highway coordinates to 2D screen space.
## string_frac: 0=left(E2) .. 1=right(e5)
## depth:       0=near (hit zone) .. 1=far (vanishing point)
func _project(string_frac: float, depth: float) -> Vector2:
	var t = 1.0 - pow(1.0 - depth, 1.8)
	var x_near = HIGHWAY_LEFT + string_frac * (HIGHWAY_RIGHT_X - HIGHWAY_LEFT)
	var x = lerp(x_near, VP.x, t)
	var y = lerp(HIT_Y, VP.y, t)
	return Vector2(x, y)

# ── drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_highway()
	_draw_notes()
	_draw_hit_zone()
	_draw_fretboard()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.02, 0.04, 0.09))
	# Subtle gradient from top (lighter) to bottom (dark)
	for i in 12:
		var alpha = (1.0 - float(i) / 12.0) * 0.25
		var h = float(i) * 45.0
		draw_rect(Rect2(0, h, VIEWPORT_W, 50.0), Color(0.05, 0.08, 0.18, alpha))

func _draw_highway() -> void:
	# Highway trapezoid (dark panel)
	var tl = _project(0.0, 1.0)
	var tr = _project(1.0, 1.0)
	var br = _project(1.0, 0.0)
	var bl = _project(0.0, 0.0)
	draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), Color(0.05, 0.06, 0.15))

	# Depth / fret lines (horizontal bars in perspective)
	for i in range(1, 22):
		var d = float(i) / 22.0
		var p_l = _project(0.0, d)
		var p_r = _project(1.0, d)
		var alpha = lerp(0.45, 0.03, d)
		draw_line(p_l, p_r, Color(0.4, 0.4, 0.55, alpha), lerp(2.2, 0.4, d))

	# String lanes (colored lines converging to VP)
	for si in NUM_STRINGS:
		var frac = _string_frac(si)
		var p_near = _project(frac, 0.0)
		var p_far  = _project(frac, 1.0)
		draw_line(p_near, p_far, STRING_COLORS[si].darkened(0.3), 2.5)

func _draw_notes() -> void:
	var lookahead_ticks = LOOKAHEAD_SECS * ticks_per_sec
	# Collect visible notes, draw far-to-near (painter's algorithm)
	var visible: Array = []
	for note in notes:
		var ticks_ahead = note.tick - current_tick
		if ticks_ahead >= -note.duration_ticks and ticks_ahead <= lookahead_ticks:
			visible.append(note)
	visible.sort_custom(func(a, b):
		return (a.tick - current_tick) > (b.tick - current_tick)
	)

	for note in visible:
		var depth = _depth_for_tick(float(note.tick))
		var si = int(note.string)
		var frac = _string_frac(si)
		var col  = STRING_COLORS[si]
		var pos  = _project(frac, depth)

		var h = lerp(26.0, 3.0, depth)
		var dur_secs = float(note.duration_ticks) / max(ticks_per_sec, 1.0)
		var w = max(lerp(72.0, 9.0, depth) * clamp(dur_secs / 0.5, 0.35, 3.0), h)

		if note.fret == 0:
			# Open string: ring
			draw_arc(pos, h * 0.55, 0, TAU, 20, col, lerp(3.0, 1.0, depth))
		else:
			var rect = Rect2(pos.x - w / 2, pos.y - h / 2, w, h)
			draw_rect(rect, col)
			draw_rect(rect, col.lightened(0.5), false, lerp(2.2, 0.5, depth))
			# Fret label when close enough
			if depth < 0.45:
				var fsize = int(lerp(15.0, 7.0, depth / 0.45))
				draw_string(ThemeDB.fallback_font,
					Vector2(pos.x - fsize * 0.38, pos.y + fsize * 0.38),
					str(note.fret), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

func _draw_hit_zone() -> void:
	# White hit line at depth=0
	draw_line(_project(0.0, 0.0), _project(1.0, 0.0), Color(1, 1, 1, 0.85), 4)
	# Hit circles per string
	for si in NUM_STRINGS:
		var pos = _project(_string_frac(si), 0.0)
		var col = STRING_COLORS[si]
		draw_circle(pos, 16, col.darkened(0.2))
		draw_arc(pos, 16, 0, TAU, 32, col.lightened(0.5), 2.5)

func _draw_fretboard() -> void:
	# Flat fretboard strip at very bottom (like Rocksmith)
	draw_rect(Rect2(0, FRETBOARD_Y, VIEWPORT_W, FRETBOARD_H), Color(0.11, 0.07, 0.03))
	draw_line(Vector2(0, FRETBOARD_Y), Vector2(VIEWPORT_W, FRETBOARD_Y),
		Color(0.55, 0.55, 0.55, 0.7), 2)

	var row_h  = FRETBOARD_H / NUM_STRINGS
	var fret_w = VIEWPORT_W / NUM_FRETS

	# String rows
	for si in NUM_STRINGS:
		var y = FRETBOARD_Y + (si + 0.5) * row_h
		draw_line(Vector2(0, y), Vector2(VIEWPORT_W, y), STRING_COLORS[si], 2)

	# Fret lines
	for f in range(NUM_FRETS + 1):
		var x = f * fret_w
		draw_line(Vector2(x, FRETBOARD_Y), Vector2(x, FRETBOARD_Y + FRETBOARD_H),
			Color(0.55, 0.55, 0.55, 0.4), 1)

	# Fret number labels (inside fretboard, at bottom edge)
	for f in [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var x = f * fret_w
		draw_string(ThemeDB.fallback_font,
			Vector2(x - 8, FRETBOARD_Y + FRETBOARD_H - 4),
			str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.7, 0.2))

	# Position dot markers
	for f in DOUBLE_DOT_FRETS:
		var x = (f - 0.5) * fret_w
		if f == 12:
			draw_circle(Vector2(x, FRETBOARD_Y + row_h * 2.3), 4, Color(0.5, 0.5, 0.5, 0.6))
			draw_circle(Vector2(x, FRETBOARD_Y + row_h * 3.7), 4, Color(0.5, 0.5, 0.5, 0.6))
		else:
			draw_circle(Vector2(x, FRETBOARD_Y + FRETBOARD_H * 0.5), 4, Color(0.5, 0.5, 0.5, 0.6))

	# Finger indicator dots: one dot per string (nearest upcoming fretted note)
	var nearest_note := {}
	for si in NUM_STRINGS:
		nearest_note[si] = null
	var lookahead_ticks = 1.0 * ticks_per_sec
	for note in notes:
		var dt = note.tick - current_tick
		if dt >= 0 and dt <= lookahead_ticks:
			var si = int(note.string)
			if nearest_note[si] == null or note.tick < nearest_note[si].tick:
				nearest_note[si] = note
	var dot_r = min(row_h * 0.42, fret_w * 0.4)
	for si in NUM_STRINGS:
		var note = nearest_note[si]
		if note == null or note.fret == 0:
			continue
		var x = (note.fret - 0.5) * fret_w
		var y = FRETBOARD_Y + (si + 0.5) * row_h
		draw_circle(Vector2(x, y), dot_r, STRING_COLORS[si].lightened(0.3))
