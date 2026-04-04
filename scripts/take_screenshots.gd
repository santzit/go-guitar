## Screenshot capture script for go-guitar gameplay.
## Usage: godot --headless --path . --script res://scripts/take_screenshots.gd
## Captures 5 frames at song positions 15s, 30s, 50s, 70s, 90s.
extends SceneTree

const SONG_PATH := "res://DLC/the-ramones-baby_i_love_you_3.gp5"
const OUT_DIR   := "res://docs/screenshots"

var _scene_node: Node2D = null
var _times: Array       = [15.0, 30.0, 50.0, 70.0, 90.0]
var _labels: Array      = ["t15s", "t30s", "t50s", "t70s", "t90s"]
var _idx: int           = 0
var _frame_wait: int    = 0

func _init() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var packed = load("res://scenes/music_play.tscn")
	if packed == null:
		printerr("Cannot load music_play.tscn")
		quit(1)
		return
	_scene_node = packed.instantiate()
	get_root().add_child(_scene_node)

	if get_root().has_node("GameState"):
		get_root().get_node("GameState").current_song = SONG_PATH
	if _scene_node.has_method("_load_song"):
		_scene_node._load_song()

	_set_time_and_capture()

func _set_time_and_capture() -> void:
	if _idx >= _times.size():
		print("All screenshots saved.")
		quit(0)
		return

	_scene_node.current_time = _times[_idx]
	_scene_node.queue_redraw()
	_frame_wait = 2  # capture after 2 idle frames

func _process(delta: float) -> bool:
	if _frame_wait > 0:
		_frame_wait -= 1
		if _frame_wait == 0:
			_do_capture()
	return false  # don't quit

func _do_capture() -> void:
	var tex := get_root().get_viewport().get_texture()
	if tex == null:
		printerr("Failed to get viewport texture for %s" % _labels[_idx])
		_idx += 1
		_set_time_and_capture()
		return
	var img := tex.get_image()
	var path := "%s/%s.png" % [OUT_DIR, _labels[_idx]]
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err == OK:
		print("Saved %s" % path)
	else:
		printerr("Failed to save %s (err=%d)" % [path, err])
	_idx += 1
	_set_time_and_capture()
