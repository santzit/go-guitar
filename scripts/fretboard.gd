## Fretboard -- static 24×6 fretboard strip at the hit zone (Z = 0).
##
## All visual elements are instantiated from .tscn component scenes.
## Mesh geometry is defined in the scene files; this script handles
## positioning, coloring, and per-frame finger indicator updates.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes (mesh geometry lives here, not in code) ──────────────────
const _SCENE_FRET_WIRE     := preload("res://scenes/components/FretWire.tscn")
const _SCENE_FRET_WIRE_OCT := preload("res://scenes/components/FretWireOct.tscn")
const _SCENE_STRING_LINE   := preload("res://scenes/components/StringLine.tscn")
const _SCENE_INLAY_DOT     := preload("res://scenes/components/InlayDot.tscn")
const _SCENE_FINGER_IND    := preload("res://scenes/components/FingerIndicator.tscn")

# Digit scenes 0-9 for fret number display
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

# Double-dot inlay Y positions (between string rows)
const _UPPER_DOT_Y := 1.5
const _LOWER_DOT_Y := 4.5

var notes:    Array = []
var playback: float = 0.0

var _dot_nodes:  Array = []   # Array[MeshInstance3D], one per string
var _dot_frets:  Array = []   # Array[int], cached fret per indicator (-1 = none)


func _ready() -> void:
	_create_fret_wires()
	_create_string_lines()
	_create_inlay_dots()
	_create_fret_labels()
	_create_finger_indicators()


func _process(_delta: float) -> void:
	_update_finger_indicators()


# ── Static mesh builders (instantiate from .tscn) ─────────────────────────────

func _create_fret_wires() -> void:
	for f in range(GC.NUM_FRETS + 1):
		var is_oct: bool = (f == 0 or f == 12 or f == 24)
		var wire: MeshInstance3D = (
			_SCENE_FRET_WIRE_OCT.instantiate() if is_oct
			else _SCENE_FRET_WIRE.instantiate()
		)
		wire.position = Vector3(float(f), float(GC.NUM_STRINGS) * 0.5, GC.FRETBOARD_THICK * 0.5)
		add_child(wire)


func _create_string_lines() -> void:
	for vis in range(GC.NUM_STRINGS):
		var col: Color = GC.STRING_COLORS[vis]
		var line: MeshInstance3D = _SCENE_STRING_LINE.instantiate()
		# Duplicate material so each string can have its own color
		var mat: StandardMaterial3D = line.get_active_material(0).duplicate()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
		line.material_override = mat
		line.position = Vector3(
			float(GC.NUM_FRETS) * 0.5,
			GC.string_y(vis),
			GC.FRETBOARD_THICK * 0.5
		)
		add_child(line)


func _create_inlay_dots() -> void:
	for f: int in GC.DOT_FRETS:
		var fx: float = GC.fret_x(f)
		if f in GC.DOUBLE_FRETS:
			_place_inlay(fx, _UPPER_DOT_Y)
			_place_inlay(fx, _LOWER_DOT_Y)
		else:
			_place_inlay(fx, float(GC.NUM_STRINGS) * 0.5)


func _place_inlay(fx: float, fy: float) -> void:
	var dot: MeshInstance3D = _SCENE_INLAY_DOT.instantiate()
	dot.position = Vector3(fx, fy, GC.FRETBOARD_THICK + 0.12)
	add_child(dot)


func _create_fret_labels() -> void:
	# Place digit scenes below each labelled fret
	for f: int in [1, 3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var base_x: float = GC.fret_x(f)
		var base_y: float = -0.65
		var base_z: float = GC.FRETBOARD_THICK + 0.10
		_place_number(f, base_x, base_y, base_z)


## Compose a fret number from digit scenes (supports 1–24).
func _place_number(n: int, cx: float, cy: float, cz: float) -> void:
	var tens: int = n / 10
	var ones: int = n % 10
	if tens > 0:
		var d1 := _DIGIT_SCENES[tens].instantiate() as Label3D
		d1.modulate = Color(0.70, 0.70, 0.50, 0.90)
		d1.position = Vector3(cx - 0.13, cy, cz)
		add_child(d1)
		var d2 := _DIGIT_SCENES[ones].instantiate() as Label3D
		d2.modulate = Color(0.70, 0.70, 0.50, 0.90)
		d2.position = Vector3(cx + 0.13, cy, cz)
		add_child(d2)
	else:
		var d := _DIGIT_SCENES[ones].instantiate() as Label3D
		d.modulate = Color(0.70, 0.70, 0.50, 0.90)
		d.position = Vector3(cx, cy, cz)
		add_child(d)


func _create_finger_indicators() -> void:
	for si in range(GC.NUM_STRINGS):
		var vis: int   = GC.vis_for_si(si)
		var col: Color = GC.STRING_COLORS[vis]

		var ind: MeshInstance3D = _SCENE_FINGER_IND.instantiate()
		var mat: StandardMaterial3D = ind.get_active_material(0).duplicate()
		mat.albedo_color = col
		ind.material_override = mat
		ind.visible = false
		add_child(ind)
		_dot_nodes.append(ind)
		_dot_frets.append(-1)


# ── Per-frame finger indicator update ─────────────────────────────────────────

func _update_finger_indicators() -> void:
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
				_clear_digit_children(ind)
				_dot_frets[si] = -1
			continue

		var fret: int = int(nv["fret"])
		var vis:  int = GC.vis_for_si(si)
		ind.visible  = true
		ind.position = Vector3(GC.fret_x(fret), GC.string_y(vis), GC.FRETBOARD_THICK + 0.12)

		if fret != _dot_frets[si]:
			_clear_digit_children(ind)
			_attach_digit_children(ind, fret)
			_dot_frets[si] = fret


## Remove digit scene children added previously.
func _clear_digit_children(parent: Node3D) -> void:
	for child in parent.get_children():
		child.queue_free()


## Attach digit scene children to show the fret number on the indicator face.
func _attach_digit_children(parent: Node3D, fret: int) -> void:
	var tens: int = fret / 10
	var ones: int = fret % 10
	var z_off: float = 0.12   # in front of box face (box depth = 0.20)
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
