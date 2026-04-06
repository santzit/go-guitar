extends Control

const DLC_DIR = "res://dlc/"
const FALLBACK_DLC_DIR = "user://dlc/"

@onready var song_list: VBoxContainer = $ScrollContainer/SongList
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	_load_songs()

func _load_songs() -> void:
	var songs = []
	for dir_path in [DLC_DIR, FALLBACK_DLC_DIR]:
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if fname.ends_with(".psarc"):
					songs.append({"path": dir_path + fname, "name": fname.get_basename()})
				fname = dir.get_next()
			dir.list_dir_end()

	if songs.is_empty():
		status_label.text = "No songs found in dlc/ folder"
		return

	status_label.text = ""
	for song in songs:
		var btn = Button.new()
		btn.text = song.name
		btn.pressed.connect(_on_song_pressed.bind(song.path))
		song_list.add_child(btn)

func _on_song_pressed(path: String) -> void:
	MusicPlay.current_song_path = path
	get_tree().change_scene_to_file("res://scenes/music_play.tscn")
