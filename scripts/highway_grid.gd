## HighwayGrid -- 3D perspective 24-fret × 6-string highway.
##
## Creates static MeshInstance3D objects in _ready():
##   • background plane (dark navy, lies in XZ plane)
##   • depth fret-column dividers (thin vertical boxes, one per fret boundary)
##
## The highway intentionally has NO horizontal string lines —
## they are "imaginary" per the game design requirement.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")


func _ready() -> void:
	_create_background()
	_create_fret_depth_dividers()


# ── Background ───────────────────────────────────────────────────────────────
func _create_background() -> void:
	var mesh_inst := MeshInstance3D.new()
	var plane     := PlaneMesh.new()
	# PlaneMesh lies flat in XZ by default (Y-normal).
	# Width along X = NUM_FRETS, depth along Z = LOOK_DEPTH
	plane.size = Vector2(float(GC.NUM_FRETS), GC.LOOK_DEPTH)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GC.HW_BG_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	# Centre in X, slightly below Y=0, centre in Z (negative half-depth)
	mesh_inst.position = Vector3(
		float(GC.NUM_FRETS) * 0.5,
		-0.05,
		-GC.LOOK_DEPTH * 0.5
	)
	add_child(mesh_inst)


# ── Depth fret-column dividers ────────────────────────────────────────────────
# These are the "depth lane lines" — thin vertical walls running the full
# Z-length of the highway at each fret boundary (X = 0, 1, 2 … 24).
# There are NO horizontal string lines on the highway.
func _create_fret_depth_dividers() -> void:
	for f in range(GC.NUM_FRETS + 1):
		var is_oct: bool  = (f == 0 or f == 12 or f == 24)
		var alpha: float  = 0.80 if is_oct else 0.35
		var thickness: float = GC.LANE_LINE_W * (2.0 if is_oct else 1.0)

		var mesh_inst := MeshInstance3D.new()
		var box       := BoxMesh.new()
		# X = thin, Y = full string height + small margin, Z = full look-depth
		box.size = Vector3(
			thickness,
			float(GC.NUM_STRINGS) + 0.5,
			GC.LOOK_DEPTH
		)
		mesh_inst.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(
			GC.FRET_LINE_COL.r,
			GC.FRET_LINE_COL.g,
			GC.FRET_LINE_COL.b,
			alpha
		)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat

		# Centred vertically across the string range; centred in Z
		mesh_inst.position = Vector3(
			float(f),
			float(GC.NUM_STRINGS) * 0.5,
			-GC.LOOK_DEPTH * 0.5
		)
		add_child(mesh_inst)
