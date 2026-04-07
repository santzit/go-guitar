## FingerIndicators -- rectangle box indicators showing upcoming note positions
## on the highway. Each indicator is a FingerIndicator.tscn (BoxMesh) with
## digit scene children showing the fret number.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_FINGER_IND := preload("res://scenes/components/FingerIndicator.tscn")

const _DIGIT_SCENES: Array = [
	preload("res://scenes/digits/Digit_0.tscn"),
	preload("res://scenes/digits/Digit_1.tscn"),
	preload("res://scenes/digits/Digit_2.tscn"),
	preload("res://scenes/digits/Digit_3.tscn"),
	preload("res://scenes/digits/Digit_4.tscn"),
	preload("res://scenes/digits/Digit_5.tscn"),
	preload("res://scenes/digits/Digit_6.tscn"),
	preload("res://scenes/digits/Digit_7.tscn"),
	preload("res://scenes/digits/Digit_8.tscn"),
	preload("res://scenes/digits/Digit_9.tscn"),
]

var notes:    Array = []
var playback: float = 0.0

var _dot_nodes: Array = []   # Array[MeshInstance3D], one per string
var _dot_frets: Array = []   # Array[int], last displayed fret per string (-1 = none)


func _ready() -> void:
	for si in range(GC.NUM_STRINGS):
		var vis: int   = GC.vis_for_si(si)
		var col: Color = GC.STRING_COLORS[vis]

		var ind: MeshInstance3D = _SCENE_FINGER_IND.instantiate()
		var mat: StandardMaterial3D = ind.get_active_material(0).duplicate()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.5
		ind.material_override = mat
		ind.visible = false
		add_child(ind)
		_dot_nodes.append(ind)
		_dot_frets.append(-1)


func _process(_delta: float) -> void:
	var nearest: Array = []
	nearest.resize(GC.NUM_STRINGS)

	for note: Dictionary in notes:
		var si:   int   = int(note["string_index"])
		var fret: int   = int(note["fret"])
		if fret == 0 or si < 0 or si >= GC.NUM_STRINGS:
			continue
		var tth: float = float(note["time"]) - playback
		if tth < 0.0 or tth > GC.FINGER_PREVIEW:
			continue
		if nearest[si] == null or float(note["time"]) < float(nearest[si]["time"]):
			nearest[si] = note

	for si in range(GC.NUM_STRINGS):
		var ind: MeshInstance3D = _dot_nodes[si]
		var nv: Variant = nearest[si]
		if nv == null:
			ind.visible = false
			if _dot_frets[si] != -1:
				_clear_digits(ind)
				_dot_frets[si] = -1
			continue

		var fret: int  = int(nv["fret"])
		var vis:  int  = GC.vis_for_si(si)
		var tth:  float = float(nv["time"]) - playback
		ind.visible  = true
		ind.position = Vector3(GC.lane_x(vis), 0.15, GC.note_z(tth))

		if fret != _dot_frets[si]:
			_clear_digits(ind)
			_attach_digits(ind, fret)
			_dot_frets[si] = fret


## Remove previously attached digit children.
func _clear_digits(parent: Node3D) -> void:
	for child in parent.get_children():
		child.queue_free()


## Attach digit scenes to the front face of the indicator box.
func _attach_digits(parent: Node3D, fret: int) -> void:
	var tens: int    = fret / 10
	var ones: int    = fret % 10
	var z_off: float = 0.12   # just in front of box face (box depth = 0.20)
	if tens > 0:
		var d1: Node3D = _DIGIT_SCENES[tens].instantiate()
		d1.position = Vector3(-0.14, 0.0, z_off)
		parent.add_child(d1)
		var d2: Node3D = _DIGIT_SCENES[ones].instantiate()
		d2.position = Vector3(0.14, 0.0, z_off)
		parent.add_child(d2)
	else:
		var d: Node3D = _DIGIT_SCENES[ones].instantiate()
		d.position = Vector3(0.0, 0.0, z_off)
		parent.add_child(d)
