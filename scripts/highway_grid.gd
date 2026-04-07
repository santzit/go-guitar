## HighwayGrid -- 6 flat string lanes running from Z=-HIGHWAY_LENGTH to Z=0.
##
## Layout:
##   - Dark floor (XZ PlaneMesh) spanning all lanes plus outer padding
##   - 6 colored string lane strips (one per string, running in Z direction)
##   - 7 thin lane dividers between and around the 6 lanes
##   - Bright hit line at Z=0 spanning all lanes
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_BG          := preload("res://scenes/components/HighwayBackground.tscn")
const _SCENE_STRING_LANE := preload("res://scenes/components/HighwayStringLane.tscn")
const _SCENE_HIT_LINE    := preload("res://scenes/components/HitLine.tscn")


func _ready() -> void:
	_create_background()
	_create_string_lanes()
	_create_lane_dividers()
	_create_hit_line()


# ── Floor (XZ plane) ──────────────────────────────────────────────────────────

func _create_background() -> void:
	var bg: MeshInstance3D = _SCENE_BG.instantiate()
	# Centre X at midpoint of all lanes; centre Z at half the highway depth
	bg.position = Vector3(GC.CAM_X, -0.01, -GC.HIGHWAY_LENGTH * 0.5)
	add_child(bg)


# ── String lane strips (one colored strip per string, running in Z) ───────────

func _create_string_lanes() -> void:
	for vis in range(GC.NUM_STRINGS):
		var col: Color = GC.STRING_COLORS[vis]
		var lane: MeshInstance3D = _SCENE_STRING_LANE.instantiate()
		var mat: StandardMaterial3D = lane.get_active_material(0).duplicate()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.40)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.20
		lane.material_override = mat
		# Centre on this lane's X, flush with surface, centred in Z
		lane.position = Vector3(GC.lane_x(vis), 0.01, -GC.HIGHWAY_LENGTH * 0.5)
		add_child(lane)


# ── Lane dividers (thin ridges between lanes, running in Z) ──────────────────

func _create_lane_dividers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.06, GC.HIGHWAY_LENGTH)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.50, 0.80, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 7 dividers: one before lane 0 and one after each lane
	for i in range(GC.NUM_STRINGS + 1):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(
			float(i) * GC.LANE_SPACING - GC.LANE_SPACING * 0.5,
			0.03,
			-GC.HIGHWAY_LENGTH * 0.5)
		add_child(mi)


# ── Hit line at Z=0 spanning all lanes ───────────────────────────────────────

func _create_hit_line() -> void:
	var hl: MeshInstance3D = _SCENE_HIT_LINE.instantiate()
	hl.position = Vector3(GC.CAM_X, 0.04, 0.0)
	add_child(hl)
