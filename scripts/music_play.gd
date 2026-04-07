## music_play.gd -- Orchestrator for the true-3D guitar highway (Node3D).
##
## Scene tree (music_play.tscn):
##   MusicPlay  (Node3D, this script)
##   ├── Camera3D          -- perspective view; slides in X to follow active notes
##   ├── HighwayGrid       -- flat PlaneMesh highway + depth fret dividers
##   ├── NoteField         -- pooled BoxMesh note blocks (fly in from -Z)
##   ├── FingerIndicators  -- SphereMesh + Label3D at (fret, string, depth)
##   └── Fretboard         -- static fretboard strip at Z = 0
##
## Perspective is provided entirely by Camera3D.
## No vanishing-point math; no 2D projection helpers.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

var _notes:       Array  = []
var _song_length: float  = 0.0
var _title:       String = ""
var _artist:      String = ""
var _playback:    float  = 0.0

# Camera tracking state
var _camera_x:    float  = float(GC.NUM_FRETS) * 0.5
var _target_fret: int    = 12

var _audio_player: AudioStreamPlayer = null
var _lbl_title:    Label = null
var _lbl_timer:    Label = null

@onready var _camera:    Camera3D = $Camera3D
@onready var _note_field: Node3D  = $NoteField
@onready var _finger_ind: Node3D  = $FingerIndicators
@onready var _fretboard:  Node3D  = $Fretboard


func _ready() -> void:
	_setup_hud()
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_load_song()
	_camera_x = GC.camera_x_for_fret(_target_fret)
	_apply_camera()


# ── HUD (CanvasLayer overlay, 2D labels) ─────────────────────────────────────
func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_lbl_title = Label.new()
	_lbl_title.position = Vector2(20, 16)
	_lbl_title.add_theme_font_size_override("font_size", 20)
	_lbl_title.modulate = Color(0.90, 0.92, 1.0)
	canvas.add_child(_lbl_title)

	_lbl_timer = Label.new()
	_lbl_timer.position = Vector2(20, 44)
	_lbl_timer.add_theme_font_size_override("font_size", 15)
	_lbl_timer.modulate = Color(0.55, 0.60, 0.75)
	canvas.add_child(_lbl_timer)


# ── Camera ────────────────────────────────────────────────────────────────────
func _apply_camera() -> void:
	if _camera == null:
		return
	var cx: float = _camera_x
	_camera.position = Vector3(cx, GC.CAM_HEIGHT, GC.CAM_Z_OFFSET)
	_camera.look_at(Vector3(cx, GC.CAM_LOOK_Y, GC.CAM_LOOK_Z))


# ── Song loading ──────────────────────────────────────────────────────────────
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
	_title       = info.get("title",       "Unknown") as String
	_artist      = info.get("artist",      "Unknown") as String
	_song_length = float(info.get("song_length", 0.0))
	_notes       = info.get("notes",       []) as Array
	var ogg_bytes: PackedByteArray = loader.load_audio(path)
	if ogg_bytes.size() > 0:
		var stream := AudioStreamOggVorbis.load_from_buffer(ogg_bytes)
		if stream != null:
			_audio_player.stream = stream
			_audio_player.play()
	_push_notes_to_children()


func _load_demo() -> void:
	_title       = "Demo Song"
	_artist      = "go-guitar"
	_song_length = 30.0
	var fret_map: Array[Array] = [
		[12, 14, 15, 12, 17, 15, 19, 17],  # si=0  High e
		[1,  3,  5,  7,  5,  3,  8,  10],  # si=1  B
		[2,  4,  5,  7,  9,  7,  5,  4],   # si=2  G
		[2,  3,  5,  7,  9,  7,  5,  3],   # si=3  D
		[2,  4,  5,  7,  8,  7,  5,  4],   # si=4  A
		[0,  3,  5,  7,  8,  7,  5,  3],   # si=5  Low E
	]
	var interval := 0.5
	var offset   := 0.09
	for si in range(GC.NUM_STRINGS):
		var t_start := float(si) * offset
		for beat in range(61):
			var fret := int(fret_map[si][beat % fret_map[si].size()])
			_notes.append({
				"time":         t_start + beat * interval,
				"string_index": si,
				"fret":         fret,
				"sustain":      0.0,
			})
	_push_notes_to_children()


func _push_notes_to_children() -> void:
	if _note_field != null: _note_field.notes = _notes
	if _finger_ind != null: _finger_ind.notes = _notes
	if _fretboard  != null: _fretboard.notes  = _notes


# ── Per-frame update ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Update playback clock
	if _audio_player and _audio_player.playing:
		_playback = _audio_player.get_playback_position()
	else:
		_playback += delta

	# Push new playback time to components
	if _note_field != null: _note_field.playback = _playback
	if _finger_ind != null: _finger_ind.playback = _playback
	if _fretboard  != null: _fretboard.playback  = _playback

	_update_camera(delta)
	_update_hud()


func _update_camera(delta: float) -> void:
	# Find the nearest upcoming fretted note (within look-ahead)
	var best_fret: int   = _target_fret
	var best_tth:  float = GC.LOOK_AHEAD + 1.0
	for note: Dictionary in _notes:
		var fret: int   = int(note["fret"])
		var tth:  float = float(note["time"]) - _playback
		if fret > 0 and tth >= -GC.CAM_TRACK_PAST and tth < best_tth:
			best_tth  = tth
			best_fret = fret
	_target_fret = best_fret

	var target_x: float = GC.camera_x_for_fret(_target_fret)
	_camera_x = lerpf(_camera_x, target_x, delta * GC.CAM_LERP_SPEED)
	_apply_camera()


func _update_hud() -> void:
	if _lbl_title != null:
		_lbl_title.text = "%s  -  %s" % [_artist, _title]
	if _lbl_timer != null:
		var secs  := int(_playback)
		var total := int(_song_length)
		_lbl_timer.text = "%d:%02d / %d:%02d" % [secs / 60, secs % 60, total / 60, total % 60]


# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
