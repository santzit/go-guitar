extends Node

var _music_node = null
var _idx: int = 0
const INTERVALS: Array = [20.0, 50.0, 80.0, 108.0, 128.0]
const PATHS: Array = ["/tmp/sn1.png","/tmp/sn2.png","/tmp/sn3.png",
					  "/tmp/sn4.png","/tmp/sn5.png"]

func _ready() -> void:
	# GameState is available as autoload
	GameState.current_song = "res://DLC/the-ramones-baby_i_love_you_3.gp5"
	var packed = load("res://scenes/music_play.tscn")
	_music_node = packed.instantiate()
	add_child(_music_node)
	print("Runner ready, notes=", _music_node.notes.size())

func _process(_delta: float) -> void:
	if _music_node == null or _idx >= INTERVALS.size():
		return
	var t: float = _music_node.current_time
	if t >= float(INTERVALS[_idx]):
		_take_shot_deferred(_idx)
		_idx += 1

func _take_shot_deferred(idx: int) -> void:
	call_deferred("_capture_shot", idx)

func _capture_shot(idx: int) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(str(PATHS[idx]))
		print("Saved ", PATHS[idx], " t=", snappedf(_music_node.current_time, 0.1), "s")
	else:
		print("WARN: empty image at idx=", idx)
	if idx >= INTERVALS.size() - 1:
		get_tree().quit(0)
