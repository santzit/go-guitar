## NoteField -- 3D note blocks flying through the highway.
##
## Notes are placed at their exact (fret_x, string_y, note_z) in 3D world space.
## Uses a fixed pool of MeshInstance3D / Label3D pairs for efficiency.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

const POOL_SIZE := 128   # max simultaneously visible notes

var notes:    Array = []
var playback: float = 0.0

var _pool_mi:   Array = []   # Array[MeshInstance3D]
var _pool_mats: Array = []   # Array[StandardMaterial3D]
var _pool_lbl:  Array = []   # Array[Label3D]  (fret number on each note)


func _ready() -> void:
	_build_pool()


func _process(_delta: float) -> void:
	_update_notes()


# ── Pool construction ─────────────────────────────────────────────────────────

func _build_pool() -> void:
	for _i in range(POOL_SIZE):
		var mi  := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(GC.NOTE_W, GC.NOTE_H, 0.20)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_pool_mi.append(mi)
		_pool_mats.append(mat)

		# Fret number label (child, faces camera)
		var lbl := Label3D.new()
		lbl.text         = ""
		lbl.font_size    = 18
		lbl.modulate     = Color.WHITE
		lbl.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.double_sided = true
		lbl.position     = Vector3(0.0, 0.0, 0.12)
		mi.add_child(lbl)
		_pool_lbl.append(lbl)


# ── Per-frame note placement ──────────────────────────────────────────────────

func _update_notes() -> void:
	# Gather visible notes
	var visible: Array = []
	for note: Dictionary in notes:
		var tth: float = float(note["time"]) - playback
		if tth >= -0.4 and tth <= GC.LOOK_AHEAD:
			visible.append(note)

	# Sort back-to-front so later notes draw on top
	visible.sort_custom(func(a, b): return float(a["time"]) > float(b["time"]))

	var idx := 0
	for note: Dictionary in visible:
		if idx >= POOL_SIZE:
			break
		var mi:  MeshInstance3D    = _pool_mi[idx]
		var mat: StandardMaterial3D = _pool_mats[idx]
		var lbl: Label3D            = _pool_lbl[idx]

		var si:   int   = int(note["string_index"])
		var fret: int   = int(note["fret"])
		var tth:  float = float(note["time"]) - playback
		var vis:  int   = GC.vis_for_si(si)
		var col:  Color = GC.STRING_COLORS[vis]

		mat.albedo_color = col
		mi.position  = Vector3(GC.fret_x(fret), GC.string_y(vis), GC.note_z(tth))
		mi.visible   = true
		lbl.text     = str(fret) if fret > 0 else "0"
		idx += 1

	# Hide unused pool slots
	for i in range(idx, POOL_SIZE):
		_pool_mi[i].visible = false
		_pool_lbl[i].text   = ""
