## HighwayGrid -- 3D perspective 24-fret × 6-string highway.
##
## All visual elements are instantiated from .tscn component scenes.
## No horizontal string lines on the highway (imaginary per design).
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_BG           := preload("res://scenes/components/HighwayBackground.tscn")
const _SCENE_DIVIDER      := preload("res://scenes/components/FretDepthDivider.tscn")
const _SCENE_DIVIDER_OCT  := preload("res://scenes/components/FretDepthDividerOct.tscn")


func _ready() -> void:
	_create_background()
	_create_fret_depth_dividers()


# ── Background ────────────────────────────────────────────────────────────────

func _create_background() -> void:
	var bg: MeshInstance3D = _SCENE_BG.instantiate()
	# PlaneMesh lies in XZ; rotate so its normal faces +Y (camera above)
	bg.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	bg.position = Vector3(
		float(GC.NUM_FRETS) * 0.5,
		-0.05,
		-GC.LOOK_DEPTH * 0.5
	)
	add_child(bg)


# ── Depth fret-column dividers ────────────────────────────────────────────────

func _create_fret_depth_dividers() -> void:
	for f in range(GC.NUM_FRETS + 1):
		var is_oct: bool = (f == 0 or f == 12 or f == 24)
		var div: MeshInstance3D = (
			_SCENE_DIVIDER_OCT.instantiate() if is_oct
			else _SCENE_DIVIDER.instantiate()
		)
		div.position = Vector3(
			float(f),
			float(GC.NUM_STRINGS) * 0.5,
			-GC.LOOK_DEPTH * 0.5
		)
		add_child(div)
