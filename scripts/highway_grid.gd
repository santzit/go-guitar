## HighwayGrid -- 3D perspective 24-fret × 6-string highway.
##
## All visual elements are instantiated from .tscn component scenes.
## String lane lines are thin flat lines (no walls/height) colored per string.
## No vertical depth dividers — fret boundaries are imaginary.
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_BG          := preload("res://scenes/components/HighwayBackground.tscn")
const _SCENE_STRING_LANE := preload("res://scenes/components/HighwayStringLane.tscn")


func _ready() -> void:
	_create_background()
	_create_string_lanes()


# ── Background ────────────────────────────────────────────────────────────────

func _create_background() -> void:
	var bg: MeshInstance3D = _SCENE_BG.instantiate()
	bg.position = Vector3(
		float(GC.NUM_FRETS) * 0.5,
		-0.05,
		-GC.LOOK_DEPTH * 0.5
	)
	add_child(bg)


# ── String lane lines (thin flat, colored per string, run full depth) ─────────

func _create_string_lanes() -> void:
	for vis in range(GC.NUM_STRINGS):
		var col: Color = GC.STRING_COLORS[vis]
		var lane: MeshInstance3D = _SCENE_STRING_LANE.instantiate()
		var mat: StandardMaterial3D = lane.get_active_material(0).duplicate()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.70)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.25
		lane.material_override = mat
		lane.position = Vector3(
			float(GC.NUM_FRETS) * 0.5,
			GC.string_y(vis),
			-GC.LOOK_DEPTH * 0.5
		)
		add_child(lane)
