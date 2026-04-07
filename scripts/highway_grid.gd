## HighwayGrid -- 3D perspective 24-fret × 6-string highway.
##
## All visual elements are instantiated from .tscn component scenes.
## No horizontal string lines and no depth dividers on the highway (imaginary).
extends Node3D

const GC = preload("res://scripts/guitar_constants.gd")

# ── Prototype scenes ──────────────────────────────────────────────────────────
const _SCENE_BG := preload("res://scenes/components/HighwayBackground.tscn")


func _ready() -> void:
	_create_background()


# ── Background ────────────────────────────────────────────────────────────────

func _create_background() -> void:
	var bg: MeshInstance3D = _SCENE_BG.instantiate()
	bg.position = Vector3(
		float(GC.NUM_FRETS) * 0.5,
		-0.05,
		-GC.LOOK_DEPTH * 0.5
	)
	add_child(bg)
