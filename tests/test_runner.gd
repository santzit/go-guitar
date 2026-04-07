## Headless test runner for go-guitar
## Usage: godot --headless --path . -s res://tests/test_runner.gd
extends SceneTree

var _pass := 0
var _fail := 0

func _assert(condition: bool, msg: String) -> void:
	if condition:
		print("  [PASS] " + msg)
		_pass += 1
	else:
		printerr("  [FAIL] " + msg)
		_fail += 1

func _init() -> void:
	print("\n-- go-guitar headless tests --")
	_test_extension_loaded()
	_test_psarc_loader()
	_test_scenes_load()
	_test_main_menu_script()
	_test_music_play_script()
	print("\n------------------------------")
	print("Results: %d passed, %d failed" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _test_extension_loaded() -> void:
	print("\n[GDExtension]")
	_assert(ClassDB.class_exists("PsarcLoader"), "PsarcLoader class registered")
	_assert(ClassDB.class_exists("PitchDetector"), "PitchDetector class registered")

func _test_psarc_loader() -> void:
	print("\n[PsarcLoader]")
	if not ClassDB.class_exists("PsarcLoader"):
		print("  (skipped - extension not loaded)")
		return

	var loader: Variant = ClassDB.instantiate("PsarcLoader")
	_assert(loader != null, "instantiate PsarcLoader")

	var res_dir := "res://tests/cdlc"
	var fs_dir  := ProjectSettings.globalize_path(res_dir)
	var dir := DirAccess.open(res_dir)
	if dir == null:
		print("  (skipped - tests/cdlc/ not found)")
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".psarc"):
			# Use real filesystem path (loader uses std::fs, not Godot VFS)
			files.append(fs_dir.path_join(f))
		f = dir.get_next()
	dir.list_dir_end()
	_assert(files.size() > 0, "found .psarc files in tests/cdlc/")

	for path: String in files:
		var fname := path.get_file()
		var arrangements: PackedStringArray = loader.list_arrangements(path)
		_assert(arrangements.size() > 0, "%s: list_arrangements >= 1" % fname)
		if arrangements.size() > 0:
			var arr := arrangements[0]
			var info: Dictionary = loader.load_notes(path, arr)
			_assert(bool(info.get("ok", false)), "%s [%s]: ok=true" % [fname, arr])
			var notes: Array = info.get("notes", [])
			_assert(notes.size() > 0, "%s [%s]: notes not empty" % [fname, arr])
			_assert(float(info.get("song_length", 0.0)) > 30.0, "%s [%s]: song_length > 30s" % [fname, arr])
			var bad_str: Array = notes.filter(func(n: Dictionary) -> bool: return int(n["string_index"]) >= 6)
			var bad_frt: Array = notes.filter(func(n: Dictionary) -> bool: return int(n["fret"]) > 24)
			var bad_tim: Array = notes.filter(func(n: Dictionary) -> bool: return float(n["time"]) < 0.0)
			_assert(bad_str.is_empty(), "%s [%s]: all string_index < 6" % [fname, arr])
			_assert(bad_frt.is_empty(), "%s [%s]: all fret <= 24" % [fname, arr])
			_assert(bad_tim.is_empty(), "%s [%s]: all time >= 0" % [fname, arr])

func _test_scenes_load() -> void:
	print("\n[Scenes]")
	for path: String in ["res://scenes/main_menu.tscn", "res://scenes/music_play.tscn"]:
		var packed: Resource = load(path)
		_assert(packed != null, path + " loads")
		if packed != null:
			var inst: Node = (packed as PackedScene).instantiate()
			_assert(inst != null, path + " instantiates")
			if inst != null:
				inst.free()

func _test_main_menu_script() -> void:
	print("\n[main_menu.gd]")
	var packed: Resource = load("res://scenes/main_menu.tscn")
	if packed == null:
		_assert(false, "main_menu.tscn loads")
		return
	var inst: Node = (packed as PackedScene).instantiate()
	_assert(inst != null, "main_menu instantiates")
	if inst == null: return
	_assert(inst.get_node_or_null("VBox/SongList") != null, "VBox/SongList present")
	_assert(inst.get_node_or_null("VBox/SongList/NoSongsLabel") != null, "NoSongsLabel present")
	inst.free()

func _test_music_play_script() -> void:
	print("\n[music_play.gd]")
	var packed: Resource = load("res://scenes/music_play.tscn")
	if packed == null:
		_assert(false, "music_play.tscn loads")
		return
	var inst: Node = (packed as PackedScene).instantiate()
	_assert(inst != null, "music_play instantiates")
	if inst != null: inst.free()
