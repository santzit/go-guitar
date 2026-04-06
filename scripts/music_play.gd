class_name MusicPlay
extends Node2D

# ── constants ──────────────────────────────────────────────────────────────────
const NUM_STRINGS      := 6
const HIT_X            := 80.0
const HIGHWAY_RIGHT    := 1280.0
const HIGHWAY_TOP      := 60.0
const HIGHWAY_BOTTOM   := 460.0
const FRETBOARD_Y      := 480.0
const FRETBOARD_HEIGHT := 240.0
const SCROLL_SPEED     := 200.0
const LOOKAHEAD_SECS   := 6.0
const TICKS_PER_BEAT   := 960
const BPM_DEFAULT      := 120.0

# String colors (E2=red, A=yellow, D=blue, G=orange, B=green, e5=purple)
const STRING_COLORS := [
	Color(1.0, 0.2, 0.2),   # E2 - red
	Color(1.0, 0.9, 0.1),   # A  - yellow
	Color(0.2, 0.5, 1.0),   # D  - blue
	Color(1.0, 0.5, 0.1),   # G  - orange
	Color(0.2, 0.9, 0.2),   # B  - green
	Color(0.8, 0.2, 1.0),   # e5 - purple
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
	var t = 0
	for measure in range(8):
		for beat in range(4):
			var string_idx = randi() % 6
			var fret = randi() % 12
			notes.append({"string": string_idx, "fret": fret, "tick": t, "duration_ticks": 480})
			t += 480
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

func _note_x(note_tick: float) -> float:
	var ticks_from_now = note_tick - current_tick
	var secs_from_now = ticks_from_now / ticks_per_sec
	var frac = secs_from_now / LOOKAHEAD_SECS
	return HIT_X + frac * (HIGHWAY_RIGHT - HIT_X)

func _string_row_y(string_idx: int) -> float:
	var row_h = (HIGHWAY_BOTTOM - HIGHWAY_TOP) / NUM_STRINGS
	return HIGHWAY_TOP + (string_idx + 0.5) * row_h

func _draw() -> void:
	_draw_highway()
	_draw_fretboard()
	_draw_notes()
	_draw_fretboard_indicators()

func _draw_highway() -> void:
	draw_rect(Rect2(0, HIGHWAY_TOP - 10, HIGHWAY_RIGHT, HIGHWAY_BOTTOM - HIGHWAY_TOP + 20), Color(0.05, 0.05, 0.1))

	for si in NUM_STRINGS:
		var y = _string_row_y(si)
		var row_h = (HIGHWAY_BOTTOM - HIGHWAY_TOP) / NUM_STRINGS
		if si % 2 == 0:
			draw_rect(Rect2(HIT_X, y - row_h / 2, HIGHWAY_RIGHT - HIT_X, row_h), Color(0.08, 0.08, 0.12))
		draw_line(Vector2(HIT_X, y), Vector2(HIGHWAY_RIGHT, y), STRING_COLORS[si].darkened(0.3), 1.5)

	draw_line(Vector2(HIT_X, HIGHWAY_TOP), Vector2(HIT_X, HIGHWAY_BOTTOM), Color(1, 1, 1, 0.8), 3)

func _draw_fretboard() -> void:
	var fb_rect = Rect2(0, FRETBOARD_Y, HIGHWAY_RIGHT, FRETBOARD_HEIGHT)
	draw_rect(fb_rect, Color(0.15, 0.10, 0.05))

	var row_h = FRETBOARD_HEIGHT / NUM_STRINGS

	for si in NUM_STRINGS:
		var y = FRETBOARD_Y + (si + 0.5) * row_h
		draw_line(Vector2(0, y), Vector2(HIGHWAY_RIGHT, y), STRING_COLORS[si], 2)

	var num_frets = 24
	for f in range(num_frets + 1):
		var x = f * (HIGHWAY_RIGHT / num_frets)
		draw_line(Vector2(x, FRETBOARD_Y), Vector2(x, FRETBOARD_Y + FRETBOARD_HEIGHT), Color(0.6, 0.6, 0.6, 0.5), 1)

	for f in [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var x = f * (HIGHWAY_RIGHT / num_frets)
		draw_string(ThemeDB.fallback_font, Vector2(x - 8, FRETBOARD_Y + FRETBOARD_HEIGHT + 15), str(f),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.7, 0.2))

	for f in DOUBLE_DOT_FRETS:
		var x = (f - 0.5) * (HIGHWAY_RIGHT / num_frets)
		if f == 12:
			draw_circle(Vector2(x, FRETBOARD_Y + row_h * 2.5), 4, Color(0.5, 0.5, 0.5, 0.6))
			draw_circle(Vector2(x, FRETBOARD_Y + row_h * 3.5), 4, Color(0.5, 0.5, 0.5, 0.6))
		else:
			draw_circle(Vector2(x, FRETBOARD_Y + FRETBOARD_HEIGHT / 2), 4, Color(0.5, 0.5, 0.5, 0.6))

func _draw_notes() -> void:
	var lookahead_ticks = LOOKAHEAD_SECS * ticks_per_sec
	var row_h = (HIGHWAY_BOTTOM - HIGHWAY_TOP) / NUM_STRINGS
	var note_h = row_h * 0.6

	for note in notes:
		var ticks_from_now = note.tick - current_tick
		if ticks_from_now < -note.duration_ticks or ticks_from_now > lookahead_ticks:
			continue

		var x = _note_x(note.tick)
		if x < 0 or x > HIGHWAY_RIGHT:
			continue

		var y = _string_row_y(note.string)
		var color = STRING_COLORS[note.string]

		if note.fret == 0:
			draw_arc(Vector2(x, y), note_h * 0.5, 0, TAU, 32, color, 2.0)
		else:
			var w = max(20.0, note.duration_ticks / ticks_per_sec * SCROLL_SPEED * 0.3)
			var rect = Rect2(x - w / 2, y - note_h / 2, w, note_h)
			draw_rect(rect, color, true, 1.0, true)
			draw_string(ThemeDB.fallback_font, Vector2(x - 6, y + 5), str(note.fret),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _draw_fretboard_indicators() -> void:
	var num_frets = 24
	var fret_w = HIGHWAY_RIGHT / num_frets
	var row_h = FRETBOARD_HEIGHT / NUM_STRINGS
	var lookahead_ticks = 1.0 * ticks_per_sec

	var nearest_note = {}
	for si in NUM_STRINGS:
		nearest_note[si] = null

	for note in notes:
		var dt = note.tick - current_tick
		if dt >= 0 and dt <= lookahead_ticks:
			var si = note.string
			if nearest_note[si] == null or note.tick < nearest_note[si].tick:
				nearest_note[si] = note

	for si in NUM_STRINGS:
		var note = nearest_note[si]
		if note == null or note.fret == 0:
			continue
		var x = (note.fret - 0.5) * fret_w
		var y = FRETBOARD_Y + (si + 0.5) * row_h
		var radius = min(row_h * 0.42, fret_w * 0.4)
		draw_circle(Vector2(x, y), radius, STRING_COLORS[si].lightened(0.3))
