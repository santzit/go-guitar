extends SceneTree

# Takes screenshots during music_play scene for visual testing.
# Run with: DISPLAY=:99 godot --path . --script res://scripts/take_screenshots.gd

var screenshot_count := 0
const MAX_SCREENSHOTS := 5
const INTERVAL_FRAMES := 180   # ~3 seconds at 60fps
var frame_counter := 0
var music_play_scene = null
var screenshots_dir := ""

func _initialize() -> void:
	screenshots_dir = ProjectSettings.globalize_path("user://screenshots/")
	DirAccess.make_dir_recursive_absolute(screenshots_dir)
	var scene_res = load("res://scenes/music_play.tscn")
	if scene_res == null:
		printerr("ERROR: Could not load music_play.tscn")
		quit(1)
		return
	music_play_scene = scene_res.instantiate()
	get_root().add_child(music_play_scene)
	print("Screenshot capture started. Will take %d screenshots." % MAX_SCREENSHOTS)

func _process(delta: float) -> bool:
	frame_counter += 1

	if screenshot_count >= MAX_SCREENSHOTS:
		print("Done! Took %d screenshots in %s" % [screenshot_count, screenshots_dir])
		quit()
		return true

	if frame_counter % INTERVAL_FRAMES == 0:
		_take_screenshot()

	return false

func _take_screenshot() -> void:
	screenshot_count += 1
	var path = screenshots_dir + "screenshot_%02d.png" % screenshot_count
	var img = get_root().get_viewport().get_texture().get_image()
	if img == null:
		printerr("Screenshot %d: viewport image is null" % screenshot_count)
		return
	var err = img.save_png(path)
	if err == OK:
		print("Screenshot %d saved: %s" % [screenshot_count, path])
	else:
		printerr("Screenshot %d failed (err=%d): %s" % [screenshot_count, err, path])
