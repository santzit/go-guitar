extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	print("Running music_play tests...")
	_test_note_x_positions()
	_test_string_row_y()
	_test_demo_notes()
	_test_psarc_parser()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func assert_eq(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS: " + label)
		passed += 1
	else:
		print("  FAIL: " + label + " got=" + str(got) + " expected=" + str(expected))
		failed += 1

func assert_approx(label: String, got: float, expected: float, tol: float = 1.0) -> void:
	if abs(got - expected) <= tol:
		print("  PASS: " + label)
		passed += 1
	else:
		print("  FAIL: " + label + " got=" + str(got) + " expected~=" + str(expected))
		failed += 1

func assert_true(label: String, condition: bool) -> void:
	if condition:
		print("  PASS: " + label)
		passed += 1
	else:
		print("  FAIL: " + label)
		failed += 1

func _test_note_x_positions() -> void:
	print("Test: note X positions")
	var scene = preload("res://scripts/music_play.gd").new()
	scene.ticks_per_sec = 960.0  # 60 BPM * 960 ticks/beat
	scene.current_tick = 0.0

	var x_now = scene._note_x(0.0)
	assert_approx("note at current_tick is at HIT_X", x_now, 80.0)

	var x_future = scene._note_x(scene.ticks_per_sec * 6.0)
	assert_approx("note 6s ahead is at HIGHWAY_RIGHT", x_future, 1280.0)

	scene.free()

func _test_string_row_y() -> void:
	print("Test: string row Y positions")
	var scene = preload("res://scripts/music_play.gd").new()

	var y0 = scene._string_row_y(0)
	var y5 = scene._string_row_y(5)
	assert_true("string 0 Y is within highway", y0 >= 60.0 and y0 <= 460.0)
	assert_true("string 5 Y is within highway", y5 >= 60.0 and y5 <= 460.0)
	assert_true("string 0 Y < string 5 Y (top to bottom)", y0 < y5)

	scene.free()

func _test_demo_notes() -> void:
	print("Test: demo notes generation")
	var scene = preload("res://scripts/music_play.gd").new()
	scene._load_demo_notes()

	assert_true("demo notes not empty", scene.notes.size() > 0)
	assert_true("notes are sorted by tick", _is_sorted(scene.notes))

	for note in scene.notes:
		assert_true("note string in range 0-5", note.string >= 0 and note.string <= 5)
		assert_true("note fret >= 0", note.fret >= 0)
		assert_true("note has duration", note.duration_ticks > 0)

	scene.free()

func _test_psarc_parser() -> void:
	print("Test: PSARC parser")
	var PsarcParserClass = preload("res://scripts/psarc_parser.gd")
	var parser = PsarcParserClass.new()
	var data = parser._get_demo_song_data()

	assert_true("demo data has notes", data.has("notes"))
	assert_true("demo data has bpm", data.has("bpm"))
	assert_true("demo notes not empty", data.notes.size() > 0)

	for note in data.notes:
		assert_true("note string 0-5", note.string >= 0 and note.string <= 5)
		assert_true("note fret >= 0", note.fret >= 0)

func _is_sorted(notes: Array) -> bool:
	for i in range(1, notes.size()):
		if notes[i].tick < notes[i - 1].tick:
			return false
	return true
