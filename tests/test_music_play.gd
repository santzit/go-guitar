extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	print("Running music_play tests...")
	_test_perspective_projection()
	_test_depth_for_tick()
	_test_string_frac()
	_test_demo_notes()
	_test_psarc_parser()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func assert_approx(label: String, got: float, expected: float, tol: float = 2.0) -> void:
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

func assert_eq(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS: " + label)
		passed += 1
	else:
		print("  FAIL: " + label + " got=" + str(got) + " expected=" + str(expected))
		failed += 1

func _test_perspective_projection() -> void:
	print("Test: perspective projection")
	var scene = preload("res://scripts/music_play.gd").new()
	scene.ticks_per_sec = 960.0
	scene.current_tick = 0.0

	# At depth=0, y should be at HIT_Y
	var p_near = scene._project(0.5, 0.0)
	assert_approx("center at depth 0 is at HIT_Y", p_near.y, scene.HIT_Y, 5.0)

	# At depth=1, should be near VP
	var p_far = scene._project(0.5, 1.0)
	assert_approx("center at depth 1 y near VP.y", p_far.y, scene.VP.y, 5.0)
	assert_approx("center at depth 1 x near VP.x", p_far.x, scene.VP.x, 5.0)

	# Left string must be left of center, right must be right at hit zone
	var p_left = scene._project(0.0, 0.0)
	var p_right = scene._project(1.0, 0.0)
	assert_true("left < center < right at hit zone",
		p_left.x < p_near.x and p_near.x < p_right.x)

	# All strings converge toward VP (y decreases) with depth
	for si in scene.NUM_STRINGS:
		var frac = scene._string_frac(si)
		var p0 = scene._project(frac, 0.0)
		var p1 = scene._project(frac, 1.0)
		assert_true("string %d y decreases toward VP" % si, p1.y < p0.y)

	scene.free()

func _test_depth_for_tick() -> void:
	print("Test: depth_for_tick")
	var scene = preload("res://scripts/music_play.gd").new()
	scene.ticks_per_sec = 960.0
	scene.current_tick = 0.0

	# Note at current tick has depth ~0
	assert_approx("note at current_tick depth ~0",
		scene._depth_for_tick(0.0), 0.0, 0.05)

	# Note at LOOKAHEAD_SECS ahead has depth ~1
	var far_tick = scene.LOOKAHEAD_SECS * scene.ticks_per_sec
	assert_approx("note at lookahead depth ~1",
		scene._depth_for_tick(far_tick), 1.0, 0.05)

	# Past notes clamp to 0
	assert_approx("past note clamps to 0",
		scene._depth_for_tick(-9999.0), 0.0, 0.05)

	# Far future clamps to 1
	assert_approx("note beyond lookahead clamps to 1",
		scene._depth_for_tick(far_tick * 3), 1.0, 0.05)

	# Intermediate: half lookahead should be between 0 and 1
	var d_half = scene._depth_for_tick(far_tick * 0.5)
	assert_true("half-lookahead depth is between 0 and 1", d_half > 0.0 and d_half < 1.0)

	scene.free()

func _test_string_frac() -> void:
	print("Test: string_frac")
	var scene = preload("res://scripts/music_play.gd").new()

	# All fracs strictly in (0, 1)
	for si in scene.NUM_STRINGS:
		var frac = scene._string_frac(si)
		assert_true("string %d frac in (0,1)" % si, frac > 0.0 and frac < 1.0)

	# Fracs are strictly increasing: E2 (left/0) < ... < e5 (right/5)
	for si in range(scene.NUM_STRINGS - 1):
		var f0 = scene._string_frac(si)
		var f1 = scene._string_frac(si + 1)
		assert_true("string %d frac < string %d frac" % [si, si + 1], f0 < f1)

	scene.free()

func _test_demo_notes() -> void:
	print("Test: demo notes generation")
	var scene = preload("res://scripts/music_play.gd").new()
	scene._load_demo_notes()

	assert_true("demo notes not empty", scene.notes.size() > 0)
	assert_true("notes sorted by tick", _is_sorted(scene.notes))

	for note in scene.notes:
		assert_true("note string in range 0-5",
			note.string >= 0 and note.string <= 5)
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
		assert_true("note string 0-5",
			note.string >= 0 and note.string <= 5)
		assert_true("note fret >= 0", note.fret >= 0)

func _is_sorted(notes: Array) -> bool:
	for i in range(1, notes.size()):
		if notes[i].tick < notes[i - 1].tick:
			return false
	return true
