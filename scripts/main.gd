extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/PlaySongsButton.pressed.connect(_on_play_songs_pressed)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_songs_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/song_list.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
