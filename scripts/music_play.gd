## music_play.gd -- Rocksmith-style 3-D perspective highway renderer
##
## String mapping (in Rocksmith SNG/PSARC data):
##   string_index 0 = High e (thinnest) --> rightmost lane (LANE_X[5])
##   string_index 5 = Low  E (thickest) --> leftmost  lane (LANE_X[0])
## So _project() reverses: visual_si = NUM_STRINGS-1 - string_index
extends Node2D

const VP          := Vector2(640, 120)
const HIT_Y       := 600.0
const LOOK_AHEAD  := 5.0
const NUM_STRINGS := 6
const FRETBOARD_Y := 615.0
const FRETBOARD_H := 105.0
const NUM_FRETS   := 24
const FINGER_PREVIEW := 3.0

# X positions of each lane at the hit zone, left=Low E, right=High e
const LANE_X: Array[float] = [120.0, 304.0, 488.0, 672.0, 856.0, 1040.0]

# Note colours (index matches visual lane, 0=Low E left to 5=High e right)
const STRING_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.55),   # Low  E  grey
	Color(1.00, 0.85, 0.00),   # A       yellow
	Color(0.10, 0.55, 1.00),   # D       blue
	Color(1.00, 0.25, 0.10),   # G       red
	Color(1.00, 0.50, 0.05),   # B       orange
	Color(0.20, 0.90, 0.20),   # High e  green
]

# Highway colours
const HIT_COLOR    := Color(1.0, 1.0, 1.0, 0.9)
const LANE_COLOR   := Color(0.35, 0.60, 0.95, 0.55)  # light blue lane dividers
const STRING_LINE  := Color(0.45, 0.70, 1.00, 0.40)  # faint light blue string traces
const HW_BG_COLOR  := Color(0.04, 0.05, 0.12, 1.0)   # very dark navy
const FB_BG_COLOR  := Color(0.08, 0.06, 0.04, 1.0)
const FB_FT_COLOR  := Color(0.30, 0.28, 0.22, 1.0)
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
	var t := 0.0
	# Spread notes across all 6 strings with ascending fret patterns
	var patterns: Array[Array] = [
		[0, 3, 5, 7, 5, 3],    # Low E  (si=5 in SNG = leftmost lane)
		[0, 2, 4, 5, 4, 2],    # A
		[0, 2, 3, 5, 3, 2],    # D
		[0, 2, 4, 5, 4, 2],    # G
		[0, 1, 3, 5, 3, 1],    # B
		[12, 14, 15, 17, 15, 14], # High e (si=0 in SNG = rightmost lane)
	]
	# Interleave strings so notes are visible across all lanes
	for beat in range(18):
		for si in range(6):
			var fi: int = patterns[si][beat % patterns[si].size()]
			_notes.append({"time": t, "string_index": si, "fret": fi, "sustain": 0.0})
			t += 0.04
		t += 0.08

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

## _draw_highway: dark navy background + light-blue lane lines (no string colours)
func _draw_highway() -> void:
	# Background
	draw_rect(Rect2(0, VP.y, 1280, HIT_Y - VP.y + 2.0), HW_BG_COLOR)
	
	# Lane divider lines (7 lines for 6 lanes) -- light blue, converge at VP
	for i in range(NUM_STRINGS + 1):
		var t_ := float(i) / float(NUM_STRINGS)
		# Bottom X: evenly spaced between left edge of lane 0 and right edge of lane 5
		var bx := lerpf(LANE_X[0] - 30.0, LANE_X[NUM_STRINGS - 1] + 30.0, t_)
		draw_line(Vector2(VP.x, VP.y), Vector2(bx, HIT_Y), LANE_COLOR, 1.0)
	
	# Faint string-centre traces (no colour -- same light blue, thinner)
	for si in range(NUM_STRINGS):
		var lx := LANE_X[si]
		draw_line(Vector2(VP.x, VP.y), Vector2(lx, HIT_Y), STRING_LINE, 1.0)
	
	# Hit zone line (bright white)
	draw_line(Vector2(0, HIT_Y), Vector2(1280, HIT_Y), HIT_COLOR, 3.0)
	
	# String labels at hit zone (so player knows which lane = which string)
	var font := ThemeDB.fallback_font
	var string_names := ["E", "A", "D", "G", "B", "e"]
	for si in range(NUM_STRINGS):
		# Lane i in data: _lane_x(si) maps si=0(High e)→right, si=5(Low E)→left
		var lx := _lane_x(si)
		draw_string(font, Vector2(lx - 6.0, HIT_Y + 14.0), string_names[5 - si],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, STRING_COLORS[si])

## _draw_notes: notes colour-coded by string, projected to correct lane
func _draw_notes() -> void:
	for note: Dictionary in _notes:
		var si   := int(note["string_index"])
		var fret := int(note["fret"])
		var t    := float(note["time"])
		var sus  := float(note["sustain"])
		var tth  := t - _playback
		if tth < -0.5 or tth > LOOK_AHEAD:
			continue
		# colour from visual lane index (si=0 High e = green, si=5 Low E = grey)
		var vis  := _vis_si(si)
		var col  := STRING_COLORS[vis]
		var depth := clampf(tth / LOOK_AHEAD, 0.0, 1.0)
		var pos   := _project(si, depth)
		var scale := lerpf(1.0, 0.18, depth)
		var hw    := 28.0 * scale
		if fret == 0:
			draw_arc(pos, hw * 0.7, 0, TAU, 32, col, 2.5 * scale)
		else:
			var r := Rect2(pos - Vector2(hw, hw * 0.45), Vector2(hw * 2, hw * 0.9))
			draw_rect(r, col)
			draw_rect(r, col.lightened(0.45), false, 1.5 * scale)
			if scale > 0.35:
				draw_string(ThemeDB.fallback_font, pos - Vector2(hw * 0.5, -hw * 0.32),
					str(fret), HORIZONTAL_ALIGNMENT_CENTER, -1, int(hw * 0.9), Color.WHITE)
		if sus > 0.05:
			var tth_end := (t + sus) - _playback
			if tth_end > -0.5:
				var depth_end := clampf(tth_end / LOOK_AHEAD, 0.0, 1.0)
				draw_line(_project(si, depth_end), pos, col.darkened(0.25), 6.0 * scale)

func _draw_fretboard() -> void:
	draw_rect(Rect2(0, FRETBOARD_Y, 1280, FRETBOARD_H), FB_BG_COLOR)
	for f in range(NUM_FRETS + 1):
		var fx := _fret_x(f)
		draw_line(Vector2(fx, FRETBOARD_Y), Vector2(fx, FRETBOARD_Y + FRETBOARD_H), FB_FT_COLOR, 1.5)
	var row_h := FRETBOARD_H / float(NUM_STRINGS)
	# String rows: row 0=top = Low E (si=5), row 5=bottom = High e (si=0)
	for vis in range(NUM_STRINGS):
		var sy := FRETBOARD_Y + (vis + 0.5) * row_h
		draw_line(Vector2(0, sy), Vector2(1280, sy), STRING_COLORS[vis].darkened(0.5), 1.0)
	for f: int in DOT_FRETS:
		var fx := (_fret_x(f - 1) + _fret_x(f)) * 0.5
		if f in DOUBLE_FRETS:
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.3), 5.0, Color(0.7, 0.7, 0.5))
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.7), 5.0, Color(0.7, 0.7, 0.5))
		else:
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.5), 5.0, Color(0.7, 0.7, 0.5))
	# Finger dots: one per string, nearest upcoming fretted note
	var nearest: Array = []
	nearest.resize(NUM_STRINGS)
	for i in range(NUM_STRINGS):
		nearest[i] = null
	for note: Dictionary in _notes:
		var si  := int(note["string_index"])
		var tth := float(note["time"]) - _playback
		if tth < 0.0 or tth > FINGER_PREVIEW:
			continue
		if si < 0 or si >= NUM_STRINGS:
			continue
		if nearest[si] == null or float(note["time"]) < float(nearest[si]["time"]):
			nearest[si] = note
	for si in range(NUM_STRINGS):
		var note: Variant = nearest[si]
		if note == null:
			continue
		var fret := int(note["fret"])
		if fret == 0:
			continue
		var vis  := _vis_si(si)
		var fx   := (_fret_x(fret - 1) + _fret_x(fret)) * 0.5
		var fy   := FRETBOARD_Y + (vis + 0.5) * row_h
		var dot_r := minf(row_h * 0.42, 10.0)
		draw_circle(Vector2(fx, fy), dot_r, STRING_COLORS[vis])

func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(20, 30), "%s  -  %s" % [_artist, _title],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 1.0))
	var secs  := int(_playback)
	var total := int(_song_length)
	draw_string(font, Vector2(20, 55),
		"%d:%02d / %d:%02d" % [secs/60, secs%60, total/60, total%60],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.7))

# ── helpers ────────────────────────────────────────────────────────────────

## Map SNG string_index to visual lane index.
## SNG: 0=High e (thin), 5=Low E (thick)
## Visual: 0=Low E left, 5=High e right  =>  vis = NUM_STRINGS-1 - si
func _vis_si(si: int) -> int:
	return NUM_STRINGS - 1 - clampi(si, 0, NUM_STRINGS - 1)

## X position at hit zone for SNG string_index si.
func _lane_x(si: int) -> float:
	return LANE_X[_vis_si(si)]

## 3-D perspective projection: returns screen position for note at given depth.
## depth 0 = at hit zone (HIT_Y), depth 1 = at vanishing point (VP).
func _project(si: int, depth: float) -> Vector2:
	var lx := _lane_x(si)
	return Vector2(lerpf(lx, VP.x, depth), lerpf(HIT_Y, VP.y, depth))

func _fret_x(fret: int) -> float:
	return 10.0 + float(fret) * (1260.0 / float(NUM_FRETS))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
