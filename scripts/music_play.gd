## music_play.gd — Rocksmith-style 3-D perspective highway renderer
##
## String mapping (Rocksmith SNG/PSARC convention):
##   SNG string_index 0 = High e (thin)  →  rightmost visual lane (vis=5)
##   SNG string_index 5 = Low  E (thick) →  leftmost  visual lane (vis=0)
##   Conversion: vis = NUM_STRINGS - 1 - si
##
## LANE_X[vis]: screen X of each lane at HIT_Y (vis=0 left, vis=5 right)
extends Node2D

const VP          := Vector2(640, 130)
const HIT_Y       := 595.0
const LOOK_AHEAD  := 5.0
const NUM_STRINGS := 6
const FRETBOARD_Y := 608.0
const FRETBOARD_H := 108.0
const NUM_FRETS   := 24
const FINGER_PREVIEW := 3.0

# Lane X at hit zone: vis=0 Low-E (left) … vis=5 High-e (right)
const LANE_X: Array[float] = [110.0, 294.0, 478.0, 662.0, 846.0, 1030.0]

# Rocksmith 2014 string colours (vis index: 0=Low E … 5=High e)
const STRING_COLORS: Array[Color] = [
	Color(0.85, 0.10, 0.10),   # Low E   — red
	Color(1.00, 0.80, 0.00),   # A       — yellow
	Color(0.05, 0.50, 1.00),   # D       — blue
	Color(1.00, 0.40, 0.00),   # G       — orange
	Color(0.10, 0.85, 0.10),   # B       — green
	Color(0.25, 0.90, 1.00),   # High e  — cyan
]

const HIT_COLOR   := Color(1.0, 1.0, 1.0, 0.95)
const HW_BG       := Color(0.02, 0.03, 0.08, 1.0)   # very dark navy
const LANE_COLOR  := Color(0.35, 0.70, 0.95, 0.75)  # light blue — all highway lines
const FRET_COL    := Color(0.35, 0.70, 0.95, 0.40)  # light blue fret grid lines
const FB_BG_COLOR := Color(0.07, 0.05, 0.03, 1.0)
const FB_FT_COLOR := Color(0.28, 0.25, 0.18, 1.0)
const DOT_FRETS    := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
const DOUBLE_FRETS := [12, 24]

var _notes: Array = []
var _song_length: float = 0.0
var _title: String = ""
var _artist: String = ""
var _playback: float = 0.0
var _audio_player: AudioStreamPlayer = null

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_load_song()

func _load_song() -> void:
	var params := get_tree().root.get_node_or_null("MusicPlayParams")
	if params == null:
		_load_demo()
		return
	var path := params.get_meta("psarc_path", "") as String
	var arr  := params.get_meta("arrangement", "lead") as String
	if not ClassDB.class_exists("PsarcLoader"):
		_load_demo()
		return
	var loader: Variant = ClassDB.instantiate("PsarcLoader")
	var info: Dictionary = loader.load_notes(path, arr)
	if not bool(info.get("ok", false)):
		push_warning("PsarcLoader: " + str(info.get("error", "?")))
		_load_demo()
		return
	_title       = info.get("title",   "Unknown") as String
	_artist      = info.get("artist",  "Unknown") as String
	_song_length = float(info.get("song_length", 0.0))
	_notes       = info.get("notes",   []) as Array
	var ogg_bytes: PackedByteArray = loader.load_audio(path)
	if ogg_bytes.size() > 0:
		var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_buffer(ogg_bytes)
		if stream != null:
			_audio_player.stream = stream
			_audio_player.play()

func _load_demo() -> void:
	_title  = "Demo Song"
	_artist = "go-guitar"
	_song_length = 30.0
	# Each string gets its own independent note stream every 0.5 s, offset by
	# 0.1 s per string so notes are always spread across all lanes at once.
	# si=0=High e (rightmost), si=5=Low E (leftmost)
	var fret_map: Array[Array] = [
		[12, 14, 15, 12, 17, 15],  # si=0  High e
		[0, 1, 3, 5, 3, 1],        # si=1  B
		[0, 2, 4, 5, 4, 2],        # si=2  G
		[2, 3, 5, 7, 5, 3],        # si=3  D
		[2, 4, 5, 7, 5, 4],        # si=4  A
		[0, 3, 5, 7, 5, 3],        # si=5  Low E (leftmost)
	]
	var interval := 0.5   # notes per string every 0.5 s
	var offset   := 0.09  # stagger each string by 0.09 s
	for si in range(NUM_STRINGS):
		var t_start := float(si) * offset
		for beat in range(61):
			var fi: int = fret_map[si][beat % fret_map[si].size()]
			_notes.append({"time": t_start + beat * interval, "string_index": si,
				"fret": fi, "sustain": 0.0})

func _process(delta: float) -> void:
	if _audio_player and _audio_player.playing:
		_playback = _audio_player.get_playback_position()
	else:
		_playback += delta
	queue_redraw()

func _draw() -> void:
	_draw_highway()
	_draw_notes()
	_draw_fretboard()
	_draw_hud()

# ─────────────────────────────────────────────────────────────────────────────
# Highway: dark background, uniform light-blue lane lines, fret grid, hit zone
# ─────────────────────────────────────────────────────────────────────────────
func _draw_highway() -> void:
	# --- Background ---
	draw_rect(Rect2(0, 0, 1280, HIT_Y + 2.0), HW_BG)

	# --- Lane lines: uniform light blue, one per string + 2 edge borders ---
	# All lines connect from vanishing point (VP) down to the string position
	# at the hit zone (HIT_Y) — no per-string colour.
	var edge_l := LANE_X[0] - 30.0
	var edge_r := LANE_X[NUM_STRINGS - 1] + 30.0
	draw_line(Vector2(VP.x, VP.y), Vector2(edge_l, HIT_Y), LANE_COLOR, 2.0)
	draw_line(Vector2(VP.x, VP.y), Vector2(edge_r, HIT_Y), LANE_COLOR, 2.0)
	for vis in range(NUM_STRINGS):
		draw_line(Vector2(VP.x, VP.y), Vector2(LANE_X[vis], HIT_Y), LANE_COLOR, 1.2)

	# --- Fret-depth grid: horizontal lines at regular depth steps ---
	for step in range(1, 12):
		var depth := float(step) / 11.0
		var y := lerpf(HIT_Y, VP.y, depth)
		var alpha := lerpf(0.45, 0.07, depth)
		var left_x  := lerpf(edge_l, VP.x, depth)
		var right_x := lerpf(edge_r, VP.x, depth)
		draw_line(Vector2(left_x, y), Vector2(right_x, y),
			Color(FRET_COL.r, FRET_COL.g, FRET_COL.b, alpha), 0.8)

	# --- Hit zone (bright white line) ---
	draw_line(Vector2(0, HIT_Y), Vector2(1280, HIT_Y), HIT_COLOR, 3.5)

	# --- String indicators at hit zone (colored, so player knows which string) ---
	for vis in range(NUM_STRINGS):
		var lx := LANE_X[vis]
		var col := STRING_COLORS[vis]
		draw_circle(Vector2(lx, HIT_Y), 10.0, col.darkened(0.25))
		draw_arc(Vector2(lx, HIT_Y), 10.0, 0, TAU, 32, col, 2.0)

# ─────────────────────────────────────────────────────────────────────────────
# Notes
# ─────────────────────────────────────────────────────────────────────────────
func _draw_notes() -> void:
	# Sort far-to-near so closer notes render on top (painter's algorithm)
	var visible: Array = []
	for note: Dictionary in _notes:
		var tth := float(note["time"]) - _playback
		if tth >= -0.5 and tth <= LOOK_AHEAD:
			visible.append(note)
	visible.sort_custom(func(a, b): return float(a["time"]) > float(b["time"]))
	
	for note: Dictionary in visible:
		var si   := int(note["string_index"])
		var fret := int(note["fret"])
		var t    := float(note["time"])
		var sus  := float(note["sustain"])
		var tth  := t - _playback
		var vis  := _vis_si(si)             # visual lane (0=Low E left … 5=High e right)
		var col  := STRING_COLORS[vis]
		var depth := clampf(tth / LOOK_AHEAD, 0.0, 1.0)
		var pos   := _project(si, depth)
		var scale := lerpf(1.0, 0.15, depth)
		var hw    := 30.0 * scale
		var hh    := hw * 0.48
		
		# Sustain tail (drawn behind note)
		if sus > 0.05:
			var tth_end := (t + sus) - _playback
			if tth_end > -0.5:
				var depth_end := clampf(tth_end / LOOK_AHEAD, 0.0, 1.0)
				var pos_end := _project(si, depth_end)
				var tail_w := maxf(3.0, hw * 0.35)
				draw_line(pos_end, pos, col.darkened(0.30), tail_w)
		
		if fret == 0:
			# Open string: outlined ring
			draw_circle(pos, hw * 0.65, Color(col.r, col.g, col.b, 0.25))
			draw_arc(pos, hw * 0.65, 0, TAU, 36, col, 2.0 * scale)
		else:
			# Fretted note: rounded rectangle with bright edge + fret number
			var r := Rect2(pos.x - hw, pos.y - hh, hw * 2.0, hh * 2.0)
			draw_rect(r, col.darkened(0.10))
			draw_rect(r, col.lightened(0.50), false, maxf(1.0, 1.5 * scale))
			# Highlight top edge
			draw_line(Vector2(r.position.x + 2, r.position.y + 1),
				Vector2(r.end.x - 2, r.position.y + 1),
				Color(1, 1, 1, 0.5 * scale), maxf(1.0, 2.0 * scale))
			if scale > 0.30:
				var fs := int(maxf(8.0, hw * 0.85))
				draw_string(ThemeDB.fallback_font,
					pos + Vector2(-hw * 0.45, hh * 0.45),
					str(fret), HORIZONTAL_ALIGNMENT_CENTER, int(hw * 2.0), fs,
					Color.WHITE)

# ─────────────────────────────────────────────────────────────────────────────
# Fretboard strip (bottom)
# ─────────────────────────────────────────────────────────────────────────────
func _draw_fretboard() -> void:
	draw_rect(Rect2(0, FRETBOARD_Y, 1280, FRETBOARD_H), FB_BG_COLOR)
	
	# Fret divider lines
	for f in range(NUM_FRETS + 1):
		var fx := _fret_x(f)
		draw_line(Vector2(fx, FRETBOARD_Y), Vector2(fx, FRETBOARD_Y + FRETBOARD_H),
			FB_FT_COLOR, 1.5)
	
	# Fret number labels (selected frets)
	var font := ThemeDB.fallback_font
	for f: int in [1, 3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var fx := (_fret_x(f - 1) + _fret_x(f)) * 0.5
		draw_string(font, Vector2(fx - 5.0, FRETBOARD_Y + FRETBOARD_H - 3.0),
			str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.5, 0.8))
	
	var row_h := FRETBOARD_H / float(NUM_STRINGS)
	# String rows: vis=0 (Low E) at top, vis=5 (High e) at bottom
	# Draw each row as a colored background strip + bright center line so the
	# finger dot is clearly associated with its string.
	for vis in range(NUM_STRINGS):
		var ry := FRETBOARD_Y + vis * row_h
		var sy := ry + row_h * 0.5
		# Subtle tinted background for this string's row
		draw_rect(Rect2(0.0, ry, 1280.0, row_h),
			Color(STRING_COLORS[vis].r, STRING_COLORS[vis].g, STRING_COLORS[vis].b, 0.10))
		# Center line in the string's color (more visible than 45%-darkened)
		draw_line(Vector2(0, sy), Vector2(1280, sy),
			STRING_COLORS[vis].darkened(0.20), 1.8)
	
	# Position dot markers
	for f: int in DOT_FRETS:
		var fx := (_fret_x(f - 1) + _fret_x(f)) * 0.5
		if f in DOUBLE_FRETS:
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.28), 4.5, Color(0.7, 0.7, 0.5))
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.72), 4.5, Color(0.7, 0.7, 0.5))
		else:
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.50), 4.5, Color(0.7, 0.7, 0.5))
	
	# Finger dots: one per string, nearest upcoming FRETTED note (skip open strings).
	# We skip fret=0 here when building the array so that an open-string note
	# does not block a fretted note that is also visible ahead in the highway.
	var nearest: Array = []
	nearest.resize(NUM_STRINGS)
	for i in range(NUM_STRINGS):
		nearest[i] = null
	for note: Dictionary in _notes:
		var si   := int(note["string_index"])
		var fret := int(note["fret"])
		if fret == 0:
			continue  # skip open strings — show only fretted positions
		var tth := float(note["time"]) - _playback
		if tth < 0.0 or tth > FINGER_PREVIEW:
			continue
		if si < 0 or si >= NUM_STRINGS:
			continue
		if nearest[si] == null or float(note["time"]) < float(nearest[si]["time"]):
			nearest[si] = note
	var font_fb := ThemeDB.fallback_font
	for si in range(NUM_STRINGS):
		var note: Variant = nearest[si]
		if note == null:
			continue
		var fret := int(note["fret"])
		var vis  := _vis_si(si)
		var fx   := (_fret_x(fret - 1) + _fret_x(fret)) * 0.5
		var fy   := FRETBOARD_Y + (vis + 0.5) * row_h
		var dot_r := minf(row_h * 0.42, 10.0)
		draw_circle(Vector2(fx, fy), dot_r, STRING_COLORS[vis])
		# Fret number label above the dot so players can verify
		var fs := maxi(7, int(dot_r * 1.1))
		draw_string(font_fb, Vector2(fx - dot_r * 0.9, fy - dot_r - 1.0),
			str(fret), HORIZONTAL_ALIGNMENT_CENTER, int(dot_r * 2.5), fs,
			Color.WHITE)

# ─────────────────────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────────────────────
func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(20, 26),
		"%s  -  %s" % [_artist, _title],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.90, 0.92, 1.0))
	var secs  := int(_playback)
	var total := int(_song_length)
	draw_string(font, Vector2(20, 50),
		"%d:%02d / %d:%02d" % [secs / 60, secs % 60, total / 60, total % 60],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.55, 0.60, 0.75))

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

## Convert SNG string_index → visual lane index.
## SNG 0=High e (thin), SNG 5=Low E (thick)
## Visual 0=Low E (leftmost lane), Visual 5=High e (rightmost lane)
func _vis_si(si: int) -> int:
	return NUM_STRINGS - 1 - clampi(si, 0, NUM_STRINGS - 1)

## Screen X of the lane for a given SNG string_index.
func _lane_x(si: int) -> float:
	return LANE_X[_vis_si(si)]

## 3-D perspective projection.
## depth=0 → hit zone (HIT_Y), depth=1 → vanishing point (VP).
func _project(si: int, depth: float) -> Vector2:
	var lx := _lane_x(si)
	return Vector2(lerpf(lx, VP.x, depth), lerpf(HIT_Y, VP.y, depth))

func _fret_x(fret: int) -> float:
	return 10.0 + float(fret) * (1260.0 / float(NUM_FRETS))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
