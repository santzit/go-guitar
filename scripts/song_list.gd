extends Control

const MUSIC_PLAY_SCENE: String = "res://scenes/music_play.tscn"
const SUPPORTED_EXTENSIONS: Array = [".json", ".gp", ".gp3", ".gp4", ".gp5"]

## Paths to scan for song files.  res:// covers bundled DLC, user:// covers
## songs added by the player after installation.
const DLC_PATHS: Array = ["res://DLC/", "user://DLC/"]

func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	_load_song_list()

func _load_song_list() -> void:
	var container: VBoxContainer = $ScrollContainer/SongListContainer
	var found_any := false

	for dlc_path in DLC_PATHS:
		var dir := DirAccess.open(dlc_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				for ext in SUPPORTED_EXTENSIONS:
					if file_name.ends_with(ext):
						_add_song_entry(container, dlc_path + file_name, file_name)
						found_any = true
						break
			file_name = dir.get_next()
		dir.list_dir_end()

	if not found_any:
		var lbl := Label.new()
		lbl.text = "No songs found.\nAdd .json or .gp files to the DLC/ folder."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		container.add_child(lbl)

func _add_song_entry(container: Node, full_path: String, file_name: String) -> void:
	var song_name: String = file_name.get_basename()

	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var lbl := Label.new()
	lbl.text = song_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var play_btn := Button.new()
	play_btn.text = "  Play  "
	play_btn.custom_minimum_size = Vector2(100, 48)
	play_btn.pressed.connect(_on_play_song.bind(full_path))

	hbox.add_child(lbl)
	hbox.add_child(play_btn)
	panel.add_child(hbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)

	container.add_child(panel)
	container.add_child(spacer)

func _on_play_song(song_path: String) -> void:
	GameState.current_song = song_path
	GameState.reset_session()
	get_tree().change_scene_to_file(MUSIC_PLAY_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
