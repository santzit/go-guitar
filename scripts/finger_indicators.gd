## FingerIndicators -- finger-position dots on the highway near the hit zone.
extends Node2D

const GC = preload("res://scripts/guitar_constants.gd")

var notes:    Array = []
var playback: float = 0.0


func _draw() -> void:
	var nearest: Array = []
	nearest.resize(GC.NUM_STRINGS)
	for i in range(GC.NUM_STRINGS):
		nearest[i] = null
	for note: Dictionary in notes:
		var si:   int   = int(note["string_index"])
		var fret: int   = int(note["fret"])
		if fret == 0:
			continue
		var tth: float = float(note["time"]) - playback
		if tth < 0.0 or tth > GC.FINGER_PREVIEW:
			continue
		if si < 0 or si >= GC.NUM_STRINGS:
			continue
		if nearest[si] == null or float(note["time"]) < float(nearest[si]["time"]):
			nearest[si] = note
	for si in range(GC.NUM_STRINGS):
		var nv: Variant = nearest[si]
		if nv == null:
			continue
		var fret:  int   = int(nv["fret"])
		var vis:   int   = GC.vis_for_si(si)
		var tth:   float = float(nv["time"]) - playback
		var depth: float = GC.depth_for_tth(tth)
		var scale: float = 1.0 - depth
		var col:   Color = GC.STRING_COLORS[vis]
		var cx:    float   = GC.fret_center_x(fret)
		var cy:    float   = GC.string_y(vis)
		var pos:   Vector2 = GC.project(cx, cy, depth)
		var base_r: float = GC.string_row_h() * 0.38
		var dot_r:  float = maxf(3.0, base_r * (0.30 + 0.70 * scale))
		draw_circle(pos, dot_r + 2.5, Color(0.0, 0.0, 0.0, 0.55 * scale))
		draw_circle(pos, dot_r, col)
		draw_arc(pos, dot_r + 1.5, 0, TAU, 32,
			Color(col.r, col.g, col.b, 0.60 * scale), maxf(0.8, 1.5 * scale))
		if scale > 0.30:
			var fs: int = maxi(7, int(dot_r * 1.15))
			draw_string(ThemeDB.fallback_font,
				pos + Vector2(-dot_r, dot_r * 0.45),
				str(fret), HORIZONTAL_ALIGNMENT_CENTER,
				int(dot_r * 2.2), fs, Color.WHITE)
