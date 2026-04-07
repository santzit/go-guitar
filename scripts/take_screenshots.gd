extends SceneTree

const GC = preload("res://scripts/guitar_constants.gd")

var _tick: int = 0
var _scene: Node = null
var _times := [0.0, 7.5, 15.0, 22.5, 30.0]


func _init() -> void:
	var packed: PackedScene = load("res://scenes/music_play.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _tick >= _times.size():
		quit()
		return false
	var t: float = _times[_tick]
	var mp := _scene
	mp.set("_playback", t)
	var nf := mp.get_node_or_null("NoteField")
	var fi := mp.get_node_or_null("FingerIndicators")
	var fb := mp.get_node_or_null("Fretboard")
	if nf: nf.set("playback", t)
	if fi: fi.set("playback", t)
	if fb: fb.set("playback", t)
	# Wait one extra frame before capturing so the draw calls execute
	if _tick_rendered:
		var img := root.get_viewport().get_texture().get_image()
		var path := "res://docs/screenshots/highway_%02d.png" % (_tick + 1)
		var fs_path := ProjectSettings.globalize_path(path)
		img.save_png(fs_path)
		print("saved " + fs_path)
		_tick += 1
		_tick_rendered = false
	else:
		_tick_rendered = true
	return false

var _tick_rendered: bool = false
