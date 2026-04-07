## HighwayGrid -- 3D highway surface per Highland-design wiki spec.
##
## Layout:
##   - Single narrow surface (PlaneMesh) spanning full highway length
##   - 6 thin lane lines (one per string) running along Z
##   - Bright hit line strip at Z=0
##   - No per-fret mesh dividers (wiki: keep to 1–3 meshes total)
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_BG          := preload("res://scenes/components/HighwayBackground.tscn")
const _SCENE_STRING_LANE := preload("res://scenes/components/HighwayStringLane.tscn")
const _SCENE_HIT_LINE    := preload("res://scenes/components/HitLine.tscn")


func _ready() -> void:
	_create_background()
	_create_string_lanes()
	_create_hit_line()


# ── Surface ───────────────────────────────────────────────────────────────────

func _create_background() -> void:
	var bg: MeshInstance3D = _SCENE_BG.instantiate()
	bg.position = Vector3(0.0, -0.01, -GC.HIGHWAY_LENGTH * 0.5)
	add_child(bg)


# ── Lane lines (thin strips along Z, one per string) ─────────────────────────

func _create_string_lanes() -> void:
	for vis in range(GC.NUM_STRINGS):
		var col: Color = GC.STRING_COLORS[vis]
		var lane: MeshInstance3D = _SCENE_STRING_LANE.instantiate()
		var mat: StandardMaterial3D = lane.get_active_material(0).duplicate()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.70)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.30
		lane.material_override = mat
		lane.position = Vector3(GC.lane_x(vis), 0.0, -GC.HIGHWAY_LENGTH * 0.5)
		add_child(lane)


# ── Hit line strip at Z=0 ─────────────────────────────────────────────────────

func _create_hit_line() -> void:
	var hl: MeshInstance3D = _SCENE_HIT_LINE.instantiate()
	hl.position = Vector3(0.0, 0.01, 0.0)
	add_child(hl)
