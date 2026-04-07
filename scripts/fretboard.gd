## Fretboard -- static 24×6 fretboard strip at the hit zone (Z = 0).
##
## All visual elements are MeshInstance3D / Label3D created in _ready().
## Finger indicator dots are updated per frame in _process().
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# Double-dot inlay Y positions (between rows, using vis-row fractions)
const _UPPER_DOT_Y := 1.5   # between string rows 1 and 2
const _LOWER_DOT_Y := 4.5   # between string rows 4 and 5

var notes:    Array = []
var playback: float = 0.0

var _dot_meshes: Array = []   # Array[MeshInstance3D], one per string
var _dot_labels: Array = []   # Array[Label3D],        one per string (child of dot)


func _ready() -> void:
	_create_background()
	_create_fret_wires()
	_create_string_lines()
	_create_inlay_dots()
	_create_fret_labels()
	_create_finger_dots()


func _process(_delta: float) -> void:
	_update_finger_dots()


# ── Static mesh builders ───────────────────────────────────────────────────────

func _create_background() -> void:
	pass  # transparent — no background mesh; strings and fret wires define the fretboard


func _create_fret_wires() -> void:
	for f in range(GC.NUM_FRETS + 1):
		var is_oct: bool   = (f == 0 or f == 12 or f == 24)
		var alpha: float   = 0.90 if is_oct else 0.55
		var thickness: float = 0.05 * (2.0 if is_oct else 1.2)
		var mi  := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(thickness, float(GC.NUM_STRINGS), GC.FRETBOARD_THICK + 0.02)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(
			GC.FB_FRET_COLOR.r,
			GC.FB_FRET_COLOR.g,
			GC.FB_FRET_COLOR.b,
			alpha
		)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.position = Vector3(
			float(f),
			float(GC.NUM_STRINGS) * 0.5,
			GC.FRETBOARD_THICK * 0.5
		)
		add_child(mi)


func _create_string_lines() -> void:
	for vis in range(GC.NUM_STRINGS):
		var col: Color  = GC.STRING_COLORS[vis]
		var mi   := MeshInstance3D.new()
		var box  := BoxMesh.new()
		box.size = Vector3(float(GC.NUM_FRETS), 0.06, GC.FRETBOARD_THICK + 0.04)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.position = Vector3(
			float(GC.NUM_FRETS) * 0.5,
			GC.string_y(vis),
			GC.FRETBOARD_THICK * 0.5
		)
		add_child(mi)


func _create_inlay_dots() -> void:
	for f: int in GC.DOT_FRETS:
		var fx: float = GC.fret_x(f)
		if f in GC.DOUBLE_FRETS:
			_make_inlay(fx, _UPPER_DOT_Y)
			_make_inlay(fx, _LOWER_DOT_Y)
		else:
			_make_inlay(fx, float(GC.NUM_STRINGS) * 0.5)


func _make_inlay(fx: float, fy: float) -> void:
	var mi     := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.70, 0.50, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(fx, fy, GC.FRETBOARD_THICK + 0.12)
	add_child(mi)


func _create_fret_labels() -> void:
	for f: int in [1, 3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var lbl := Label3D.new()
		lbl.text          = str(f)
		lbl.font_size     = 18
		lbl.modulate      = Color(0.70, 0.70, 0.50, 0.90)
		lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.double_sided  = true
		lbl.position      = Vector3(GC.fret_x(f), -0.65, GC.FRETBOARD_THICK + 0.10)
		add_child(lbl)


func _create_finger_dots() -> void:
	for si in range(GC.NUM_STRINGS):
		var vis: int   = GC.vis_for_si(si)
		var col: Color = GC.STRING_COLORS[vis]

		# Sphere mesh (one per string; hidden until a note is near)
		var mi     := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.70
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_dot_meshes.append(mi)

		# Fret number label (child of the sphere so it moves with it)
		var lbl := Label3D.new()
		lbl.text         = ""
		lbl.font_size    = 22
		lbl.modulate     = Color.WHITE
		lbl.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.double_sided = true
		lbl.position     = Vector3(0.0, 0.0, 0.4)
		mi.add_child(lbl)
		_dot_labels.append(lbl)


# ── Per-frame finger dot update ───────────────────────────────────────────────

func _update_finger_dots() -> void:
	# Build nearest[si] = note closest to playback within FINGER_PREVIEW window
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
		var mi:  MeshInstance3D = _dot_meshes[si]
		var lbl: Label3D        = _dot_labels[si]
		var nv: Variant = nearest[si]
		if nv == null:
			mi.visible = false
			lbl.text   = ""
			continue

		var fret: int   = int(nv["fret"])
		var vis:  int   = GC.vis_for_si(si)
		mi.visible  = true
		mi.position = Vector3(GC.fret_x(fret), GC.string_y(vis), GC.FRETBOARD_THICK + 0.38)
		lbl.text    = str(fret)
