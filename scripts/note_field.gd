## NoteField -- 3D note blocks flying through the highway.
##
## Uses a fixed pool of NoteBlock.tscn instances for efficiency.
## Mesh geometry is defined in the NoteBlock scene; this script
## handles positioning, coloring, visibility, and fret digits.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_NOTE := preload("res://scenes/components/NoteBlock.tscn")

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

const POOL_SIZE         := 128
const VISIBILITY_BUFFER := 0.4

var notes:    Array = []
var playback: float = 0.0

var _pool_mi:    Array = []   # Array[MeshInstance3D]
var _pool_mats:  Array = []   # Array[StandardMaterial3D] (one duplicate per slot)
var _pool_frets: Array = []   # Array[int] cached fret (-1 = none)


func _ready() -> void:
	_build_pool()


func _process(_delta: float) -> void:
	_update_notes()


# ── Pool construction ─────────────────────────────────────────────────────────

func _build_pool() -> void:
	for _i in range(POOL_SIZE):
		var mi: MeshInstance3D = _SCENE_NOTE.instantiate()
		# Duplicate material so each slot can have its own string color
		var mat: StandardMaterial3D = mi.get_active_material(0).duplicate()
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 0.6
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_pool_mi.append(mi)
		_pool_mats.append(mat)
		_pool_frets.append(-1)


# ── Per-frame note placement ──────────────────────────────────────────────────

func _update_notes() -> void:
	var visible: Array = []
	for note: Dictionary in notes:
		var tth: float = float(note["time"]) - playback
		if tth >= -VISIBILITY_BUFFER and tth <= GC.LOOK_AHEAD:
			visible.append(note)

	visible.sort_custom(func(a, b): return float(a["time"]) > float(b["time"]))

	var idx := 0
	for note: Dictionary in visible:
		if idx >= POOL_SIZE:
			break
		var mi:  MeshInstance3D    = _pool_mi[idx]
		var mat: StandardMaterial3D = _pool_mats[idx]

		var si:   int   = int(note["string_index"])
		var fret: int   = int(note["fret"])
		var tth:  float = float(note["time"]) - playback
		var vis:  int   = GC.vis_for_si(si)
		var col:  Color = GC.STRING_COLORS[vis]

		mat.albedo_color = col
		mat.emission = col
		mi.position = Vector3(GC.lane_x(vis), GC.NOTE_Y, GC.note_z(tth))
		mi.visible  = true

		if fret != _pool_frets[idx]:
			_clear_digits(mi)
			if fret >= 0:
				_attach_digits(mi, fret)
			_pool_frets[idx] = fret

		idx += 1

	for i in range(idx, POOL_SIZE):
		_pool_mi[i].visible = false
		if _pool_frets[i] != -1:
			_clear_digits(_pool_mi[i])
			_pool_frets[i] = -1


func _clear_digits(parent: Node3D) -> void:
	for child in parent.get_children():
		child.queue_free()


func _attach_digits(parent: Node3D, fret: int) -> void:
	var tens: int    = fret / 10
	var ones: int    = fret % 10
	var z_off: float = 0.12
	if tens > 0:
		var d1: Node3D = _DIGIT_SCENES[tens].instantiate()
		d1.position = Vector3(-0.12, 0.0, z_off)
		parent.add_child(d1)
		var d2: Node3D = _DIGIT_SCENES[ones].instantiate()
		d2.position = Vector3(0.12, 0.0, z_off)
		parent.add_child(d2)
	else:
		var d: Node3D = _DIGIT_SCENES[ones].instantiate()
		d.position = Vector3(0.0, 0.0, z_off)
		parent.add_child(d)
