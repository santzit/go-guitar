## FingerIndicators -- 3D finger-position spheres on the highway near the hit zone.
##
## Creates 6 MeshInstance3D spheres in _ready() (one per string).
## Each sphere has a Label3D child showing the fret number.
## Both sphere and label are repositioned every frame in _process()
## to sit at the correct (fret_x, string_y, note_z) in 3D world space.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

var notes:    Array = []
var playback: float = 0.0

var _dot_meshes: Array = []   # Array[MeshInstance3D], one per string
var _dot_labels: Array = []   # Array[Label3D], one per string (child of dot)


func _ready() -> void:
	for si in range(GC.NUM_STRINGS):
		var vis: int   = GC.vis_for_si(si)
		var col: Color = GC.STRING_COLORS[vis]

		# Sphere
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

		# Fret-number label — child of the sphere, always faces camera
		var lbl := Label3D.new()
		lbl.text         = ""
		lbl.font_size    = 22
		lbl.modulate     = Color.WHITE
		lbl.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.double_sided = true
		lbl.position     = Vector3(0.0, 0.0, 0.38)
		mi.add_child(lbl)
		_dot_labels.append(lbl)


func _process(_delta: float) -> void:
	# Build nearest[si] = note closest to hit within FINGER_PREVIEW window
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
		var tth:  float = float(nv["time"]) - playback
		mi.visible  = true
		mi.position = Vector3(GC.fret_x(fret), GC.string_y(vis), GC.note_z(tth))
		lbl.text    = str(fret)
