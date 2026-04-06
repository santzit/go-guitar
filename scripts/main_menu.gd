extends Control

const DLC_DIR := "res://DLC"

@onready var song_list:         VBoxContainer = $VBox/SongList
@onready var no_songs_label:    Label         = $VBox/SongList/NoSongsLabel
@onready var arrangement_label: Label         = $VBox/ArrangementLabel

func _ready() -> void:
if not ClassDB.class_exists("PsarcLoader"):
_show_error("GDExtension not loaded.\nRun 'make ext' to build.")
return
_scan_dlc()

func _scan_dlc() -> void:
var loader := _make_loader()
if loader == null:
_show_error("PsarcLoader unavailable.")
return

var dir := DirAccess.open(DLC_DIR)
if dir == null:
no_songs_label.text = "DLC/ directory not found."
no_songs_label.visible = true
return

var files: Array[String] = []
dir.list_dir_begin()
var fname := dir.get_next()
while fname != "":
if fname.ends_with(".psarc"):
files.append(DLC_DIR.path_join(fname))
fname = dir.get_next()
dir.list_dir_end()

if files.is_empty():
no_songs_label.visible = true
return

no_songs_label.visible = false
for path in files:
_add_song_button(loader, path)

func _add_song_button(loader: Object, path: String) -> void:
var arrangements: PackedStringArray = loader.list_arrangements(path)
if arrangements.is_empty():
return

var first_arr := arrangements[0] as String
var info: Dictionary = loader.load_notes(path, first_arr)
var title  := info.get("title",  path.get_file().get_basename()) as String
var artist := info.get("artist", "") as String
var display := "%s — %s" % [artist, title] if artist != "" else title

var btn := Button.new()
btn.text = display
btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
btn.add_theme_font_size_override("font_size", 18)
btn.pressed.connect(func(): _on_song_selected(path, arrangements))
song_list.add_child(btn)

func _on_song_selected(path: String, arrangements: PackedStringArray) -> void:
if arrangements.size() == 1:
_launch(path, arrangements[0])
return

arrangement_label.text = "Choose arrangement:"
arrangement_label.visible = true

for child in song_list.get_children():
if child.has_meta("arr_picker"):
child.queue_free()

for arr in arrangements:
var btn := Button.new()
btn.text = arr.capitalize()
btn.set_meta("arr_picker", true)
btn.pressed.connect(func(): _launch(path, arr))
song_list.add_child(btn)

func _launch(path: String, arrangement: String) -> void:
# Pass metadata to the play scene via a temporary autoloaded node
var node := get_tree().root.get_node_or_null("MusicPlayParams")
if node == null:
node = Node.new()
node.name = "MusicPlayParams"
get_tree().root.add_child(node)
node.set_meta("psarc_path",  path)
node.set_meta("arrangement", arrangement)
get_tree().change_scene_to_file("res://scenes/music_play.tscn")

func _show_error(msg: String) -> void:
no_songs_label.text = msg
no_songs_label.visible = true

func _make_loader() -> Object:
if ClassDB.class_exists("PsarcLoader"):
return ClassDB.instantiate("PsarcLoader")
return null
