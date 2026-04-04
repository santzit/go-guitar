## Runs headless Godot scene tests.
## Usage: godot --headless --path /path/to/go-guitar --script res://tests/test_runner.gd
extends SceneTree

var _failed := false

func _init() -> void:
	# Defer so autoloads (GameState) are added to root before we check them.
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=== GoGuitar Scene Tests ===\n")
	_test_game_state()
	_test_main_scene()
	_test_song_list_scene()
	_test_music_play_scene()
	_test_gp_parser()
	_test_dlc_song()
	if _failed:
		printerr("\nSome tests FAILED")
		quit(1)
	else:
		print("\nAll tests PASSED")
		quit(0)

func _ok(msg: String) -> void:
	print("  PASS  " + msg)

func _fail(msg: String) -> void:
	printerr("  FAIL  " + msg)
	_failed = true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok(msg)
	else:
		_fail(msg)

# -- GameState autoload -------------------------------------------------------

func _test_game_state() -> void:
	print("--- GameState autoload ---")
	# Autoloads are children of root. call_deferred ensures they exist by now.
	_assert(get_root().has_node("GameState"),
			"GameState autoload node is present under root")
	print()

# -- Main menu scene ----------------------------------------------------------

func _test_main_scene() -> void:
	print("--- scenes/main.tscn ---")
	var packed = load("res://scenes/main.tscn")
	_assert(packed != null, "main.tscn loads")
	if packed == null:
		return
	var node = packed.instantiate()
	_assert(node != null, "main.tscn instantiates")
	_assert(node.has_node("CenterContainer/VBoxContainer/PlaySongsButton"),
			"PlaySongsButton node exists")
	_assert(node.has_node("CenterContainer/VBoxContainer/QuitButton"),
			"QuitButton node exists")
	_assert(node.get_script() != null, "main.gd script attached")
	node.free()
	print()

# -- Song-list scene ----------------------------------------------------------

func _test_song_list_scene() -> void:
	print("--- scenes/song_list.tscn ---")
	var packed = load("res://scenes/song_list.tscn")
	_assert(packed != null, "song_list.tscn loads")
	if packed == null:
		return
	var node = packed.instantiate()
	_assert(node != null, "song_list.tscn instantiates")
	_assert(node.has_node("BackButton"), "BackButton node exists")
	_assert(node.has_node("ScrollContainer/SongListContainer"),
			"SongListContainer node exists")
	_assert(node.get_script() != null, "song_list.gd script attached")
	node.free()
	print()

# -- Gameplay scene -----------------------------------------------------------

func _test_music_play_scene() -> void:
	print("--- scenes/music_play.tscn ---")
	var packed = load("res://scenes/music_play.tscn")
	_assert(packed != null, "music_play.tscn loads")
	if packed == null:
		return
	var node = packed.instantiate()
	_assert(node != null, "music_play.tscn instantiates")
	_assert(node.has_node("HUD/BackButton"),     "HUD/BackButton node exists")
	_assert(node.has_node("HUD/ScoreLabel"),     "HUD/ScoreLabel node exists")
	_assert(node.has_node("HUD/SongTitleLabel"), "HUD/SongTitleLabel node exists")
	_assert(node.get_script() != null, "music_play.gd script attached")
	node.free()
	print()

# -- GpParser GDExtension -----------------------------------------------------

func _test_gp_parser() -> void:
	print("--- GpParser GDExtension ---")
	if not ClassDB.class_exists("GpParser"):
		print("  SKIP  GpParser GDExtension not loaded (run `make ext` to build)")
		print()
		return
	var parser = ClassDB.instantiate("GpParser")
	_assert(parser != null, "GpParser instantiates via ClassDB")
	# Empty bytes must return an empty dict without crashing.
	var empty_result = parser.parse_bytes(PackedByteArray(), "gp5")
	_assert(empty_result is Dictionary, "parse_bytes returns a Dictionary on empty input")
	print()

# -- DLC test song ------------------------------------------------------------

func _test_dlc_song() -> void:
	print("--- DLC/the-ramones-baby_i_love_you_3.gp5 ---")
	const SONG := "res://DLC/the-ramones-baby_i_love_you_3.gp5"
	_assert(FileAccess.file_exists(SONG), "GP5 test file exists in DLC/")
	if not ClassDB.class_exists("GpParser"):
		print("  SKIP  (GDExtension not loaded)")
		print()
		return
	var file := FileAccess.open(SONG, FileAccess.READ)
	_assert(file != null, "GP5 file opens for reading")
	if file == null:
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()
	_assert(bytes.size() > 0, "GP5 file has non-zero bytes (%d)" % bytes.size())
	var parser = ClassDB.instantiate("GpParser")
	var data = parser.parse_bytes(bytes, "gp5")
	_assert(not data.is_empty(),         "parse_bytes returns non-empty Dictionary")
	_assert(data.has("title"),           "result has \'title\' key")
	_assert(data.has("bpm"),             "result has \'bpm\' key")
	_assert(data.has("notes"),           "result has \'notes\' key")
	_assert(data.get("bpm", 0) > 0,      "BPM is positive (%s)" % str(data.get("bpm")))
	var notes = data.get("notes", [])
	_assert(notes is Array,              "notes is an Array")
	_assert(notes.size() > 0,           "notes array is non-empty (%d notes)" % notes.size())
	if notes.size() > 0:
		var n = notes[0]
		_assert(n is Dictionary,         "first note is a Dictionary")
		_assert(n.has("time"),           "first note has \'time\'")
		_assert(n.has("string"),         "first note has \'string\'")
		_assert(n.has("fret"),           "first note has \'fret\'")
		_assert(n.has("duration"),       "first note has \'duration\'")
		_assert(float(n.get("time",    -1)) >= 0.0,      "first note time >= 0")
		_assert(int(n.get("string",    -1)) in range(6), "first note string in 0-5")
		_assert(int(n.get("fret",      -1)) >= 0,        "first note fret >= 0")
		_assert(float(n.get("duration", 0)) > 0.0,       "first note duration > 0")
	print()
