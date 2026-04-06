## music_play.gd -- Rocksmith-style 3-D perspective highway renderer
extends Node2D

const VP          := Vector2(640, 120)
const HIT_Y       := 600.0
const LOOK_AHEAD  := 5.0
const NUM_STRINGS := 6
const FRETBOARD_Y := 615.0
const FRETBOARD_H := 105.0
const NUM_FRETS   := 24
const FINGER_PREVIEW := 3.0

const LANE_X: Array[float] = [120.0, 304.0, 488.0, 672.0, 856.0, 1040.0]

const STRING_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.55),
	Color(1.00, 0.85, 0.00),
	Color(0.10, 0.55, 1.00),
	Color(1.00, 0.25, 0.10),
	Color(1.00, 0.50, 0.05),
	Color(0.20, 0.90, 0.20),
]

const HIT_COLOR   := Color(1.0, 1.0, 1.0, 0.9)
const LANE_COLOR  := Color(0.15, 0.15, 0.25, 0.85)
const FB_BG_COLOR := Color(0.08, 0.06, 0.04, 1.0)
const FB_FT_COLOR := Color(0.30, 0.28, 0.22, 1.0)
const DOT_FRETS   := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
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
	var frets := [0, 3, 5, 7, 0, 3, 5, 7, 12, 12, 12]
	for si in range(6):
		for fi in frets:
			_notes.append({"time": t, "string_index": si, "fret": fi, "sustain": 0.0})
			t += 0.18
		t += 0.3

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

func _draw_highway() -> void:
	draw_rect(Rect2(0, VP.y, 1280, HIT_Y - VP.y), Color(0.06, 0.06, 0.14))
	for si in range(NUM_STRINGS + 1):
		var t_ := float(si) / float(NUM_STRINGS)
		var bx := lerpf(LANE_X[0] - 32, LANE_X[NUM_STRINGS-1] + 32, t_)
		draw_line(Vector2(lerp(bx, VP.x, 1.0), VP.y), Vector2(bx, HIT_Y), LANE_COLOR, 1.0)
	for si in range(NUM_STRINGS):
		draw_line(
			Vector2(lerp(LANE_X[si], VP.x, 1.0), VP.y),
			Vector2(LANE_X[si], HIT_Y),
			STRING_COLORS[si].darkened(0.3), 1.5)
	draw_line(Vector2(0, HIT_Y), Vector2(1280, HIT_Y), HIT_COLOR, 3.0)

func _draw_notes() -> void:
	for note: Dictionary in _notes:
		var si   := int(note["string_index"])
		var fret := int(note["fret"])
		var t    := float(note["time"])
		var sus  := float(note["sustain"])
		var tth  := t - _playback
		if tth < -0.5 or tth > LOOK_AHEAD:
			continue
		var col   := STRING_COLORS[clampi(si, 0, 5)]
		var depth := clampf(tth / LOOK_AHEAD, 0.0, 1.0)
		var pos   := _project(si, depth)
		var scale := lerpf(1.0, 0.18, depth)
		var hw    := 28.0 * scale
		if fret == 0:
			draw_arc(pos, hw * 0.7, 0, TAU, 32, col, 2.5 * scale)
		else:
			var r := Rect2(pos - Vector2(hw, hw * 0.45), Vector2(hw * 2, hw * 0.9))
			draw_rect(r, col)
			draw_rect(r, col.lightened(0.5), false, 1.5 * scale)
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
	for si in range(NUM_STRINGS):
		var sy := FRETBOARD_Y + (si + 0.5) * row_h
		draw_line(Vector2(0, sy), Vector2(1280, sy), STRING_COLORS[si].darkened(0.5), 1.0)
	for f: int in DOT_FRETS:
		var fx := (_fret_x(f - 1) + _fret_x(f)) * 0.5
		if f in DOUBLE_FRETS:
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.3), 5.0, Color(0.7, 0.7, 0.5))
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.7), 5.0, Color(0.7, 0.7, 0.5))
		else:
			draw_circle(Vector2(fx, FRETBOARD_Y + FRETBOARD_H * 0.5), 5.0, Color(0.7, 0.7, 0.5))
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
		var fx  := (_fret_x(fret - 1) + _fret_x(fret)) * 0.5
		var fy  := FRETBOARD_Y + (si + 0.5) * row_h
		var dot_r := minf(row_h * 0.42, 10.0)
		draw_circle(Vector2(fx, fy), dot_r, STRING_COLORS[si])

func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(20, 30), "%s -- %s" % [_artist, _title],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 1.0))
	var secs  := int(_playback)
	var total := int(_song_length)
	draw_string(font, Vector2(20, 55),
		"%d:%02d / %d:%02d" % [secs/60, secs%60, total/60, total%60],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.7))

func _project(string_index: int, depth: float) -> Vector2:
	var lx := LANE_X[clampi(string_index, 0, NUM_STRINGS - 1)]
	return Vector2(lerpf(lx, VP.x, depth), lerpf(HIT_Y, VP.y, depth))

func _fret_x(fret: int) -> float:
	return 10.0 + float(fret) * (1260.0 / float(NUM_FRETS))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
