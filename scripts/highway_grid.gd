## HighwayGrid -- 3D highway: 24 fret lanes (X) × 6 string rows (Y) × depth (Z).
##
## Layout:
##   - Dark floor (XZ PlaneMesh) spanning X=0…24, Z=-24…0
##   - 6 string guide lines at Y=string_y(vis), spanning all frets and full depth
##   - 23 fret lane dividers at X=1…23, spanning all strings and full depth
##   - Bright hit panel at Z=0 marking the note-hit zone
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_BG          := preload("res://scenes/components/HighwayBackground.tscn")
const _SCENE_STRING_LANE := preload("res://scenes/components/HighwayStringLane.tscn")
const _SCENE_HIT_LINE    := preload("res://scenes/components/HitLine.tscn")


func _ready() -> void:
	_create_background()
	_create_string_lanes()
	_create_fret_dividers()
	_create_hit_line()


# ── Floor (XZ plane) ──────────────────────────────────────────────────────────

func _create_background() -> void:
	var bg: MeshInstance3D = _SCENE_BG.instantiate()
	# Centre of the 24-unit-wide, 24-unit-deep highway floor
	bg.position = Vector3(GC.HIGHWAY_WIDTH * 0.5, -0.01, -GC.HIGHWAY_LENGTH * 0.5)
	add_child(bg)


# ── String guide lines (horizontal, one per string at correct Y height) ───────

func _create_string_lanes() -> void:
	for vis in range(GC.NUM_STRINGS):
		var col: Color = GC.STRING_COLORS[vis]
		var lane: MeshInstance3D = _SCENE_STRING_LANE.instantiate()
		var mat: StandardMaterial3D = lane.get_active_material(0).duplicate()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.25
		lane.material_override = mat
		# Centred across all frets (X=12) and full highway depth (Z=-12)
		lane.position = Vector3(GC.HIGHWAY_WIDTH * 0.5, GC.string_y(vis), -GC.HIGHWAY_LENGTH * 0.5)
		add_child(lane)


# ── Fret lane dividers (thin vertical panels between each fret pair) ──────────

func _create_fret_dividers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, GC.HIGHWAY_HEIGHT + 1.0, GC.HIGHWAY_LENGTH)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.28, 0.28, 0.50, 0.40)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for f in range(1, GC.NUM_FRETS):   # dividers at X=1, 2, … 23
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(float(f), GC.HIGHWAY_HEIGHT * 0.5, -GC.HIGHWAY_LENGTH * 0.5)
		add_child(mi)


# ── Hit panel at Z=0 (bright full-height marker) ─────────────────────────────

func _create_hit_line() -> void:
	var hl: MeshInstance3D = _SCENE_HIT_LINE.instantiate()
	hl.position = Vector3(GC.HIGHWAY_WIDTH * 0.5, GC.HIGHWAY_HEIGHT * 0.5, 0.0)
	add_child(hl)
