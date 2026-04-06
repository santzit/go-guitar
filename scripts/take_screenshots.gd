extends SceneTree

# Takes screenshots during music_play scene for visual testing.
# Run with: godot --headless --path . --script res://scripts/take_screenshots.gd

var screenshot_count := 0
var MAX_SCREENSHOTS := 5
var INTERVAL_SECS := 5.0
var elapsed := 0.0
var music_play_scene = null

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://") + "screenshots")
	var scene_path = "res://scenes/music_play.tscn"
	music_play_scene = load(scene_path).instantiate()
	get_root().add_child(music_play_scene)
	print("Screenshot capture started. Will take %d screenshots." % MAX_SCREENSHOTS)

func _process(delta: float) -> bool:
	elapsed += delta
	if screenshot_count >= MAX_SCREENSHOTS:
		print("Done! Took %d screenshots." % MAX_SCREENSHOTS)
		quit()
		return false

	if elapsed >= INTERVAL_SECS * (screenshot_count + 1):
		_take_screenshot()

	return false

func _take_screenshot() -> void:
	screenshot_count += 1
	var fname = "user://screenshots/screenshot_%02d.png" % screenshot_count
	get_root().get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(fname))
	print("Screenshot %d saved to %s" % [screenshot_count, fname])
