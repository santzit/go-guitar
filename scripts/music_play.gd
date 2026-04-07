## music_play.gd -- Orchestrator for the 3D guitar highway scene.
##
## Responsibilities:
##   Load song data (from PSARC or demo)
##   Drive audio playback
##   Update child components (NoteField, FingerIndicators, Fretboard) each frame
##   Draw the HUD (song title, timer)
##
## Scene composition (music_play.tscn):
##   MusicPlay  (this script)
##   HighwayGrid     -- pure-visual 24x6 3D grid (highway_grid.gd)
##   NoteField       -- note blocks in 3D perspective (note_field.gd)
##   FingerIndicators-- finger dots on the highway (finger_indicators.gd)
##   Fretboard       -- static fretboard strip (fretboard.gd)
extends Node2D

const GC = preload("res://scripts/guitar_constants.gd")

var _notes:        Array  = []
var _song_length:  float  = 0.0
var _title:        String = ""
var _artist:       String = ""
var _playback:     float  = 0.0
var _audio_player: AudioStreamPlayer = null

@onready var _note_field: Node2D = $NoteField
@onready var _finger_ind: Node2D = $FingerIndicators
@onready var _fretboard:  Node2D = $Fretboard


func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_load_song()


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
	# One independent note stream per string, staggered 0.09 s.
	# Fret values spread across frets 1-22 to show the full 24-lane grid.
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
	if _audio_player and _audio_player.playing:
		_playback = _audio_player.get_playback_position()
	else:
		_playback += delta
	if _note_field != null:
		_note_field.playback = _playback
		_note_field.queue_redraw()
	if _finger_ind != null:
		_finger_ind.playback = _playback
		_finger_ind.queue_redraw()
	if _fretboard != null:
		_fretboard.playback = _playback
		_fretboard.queue_redraw()
	queue_redraw()


# ── HUD ───────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(20, 26),
		"%s  -  %s" % [_artist, _title],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(0.90, 0.92, 1.0))
	var secs  := int(_playback)
	var total := int(_song_length)
	draw_string(font, Vector2(20, 50),
		"%d:%02d / %d:%02d" % [secs / 60, secs % 60, total / 60, total % 60],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.55, 0.60, 0.75))


# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
