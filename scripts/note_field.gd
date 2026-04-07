## NoteField -- note blocks flying through the 24x6 3D highway.
## Each note is at its exact (fret column, string row) in the perspective grid.
extends Node2D

const GC = preload("res://scripts/guitar_constants.gd")

var notes:    Array = []
var playback: float = 0.0


func _draw() -> void:
	var visible: Array = []
	for note: Dictionary in notes:
		var tth: float = float(note["time"]) - playback
		if tth >= -0.3 and tth <= GC.LOOK_AHEAD:
			visible.append(note)
	visible.sort_custom(func(a, b): return float(a["time"]) > float(b["time"]))
	for note: Dictionary in visible:
		_draw_note(note)


func _draw_note(note: Dictionary) -> void:
	var si:    int   = int(note["string_index"])
	var fret:  int   = int(note["fret"])
	var t:     float = float(note["time"])
	var sus:   float = float(note["sustain"])
	var tth:   float = t - playback
	var vis:   int   = GC.vis_for_si(si)
	var col:   Color = GC.STRING_COLORS[vis]
	var depth: float = GC.depth_for_tth(tth)
	var scale: float = 1.0 - depth
	var cx:    float   = GC.fret_center_x(fret)
	var cy:    float   = GC.string_y(vis)
	var pos:   Vector2 = GC.project(cx, cy, depth)
	var fret_w: float = (GC.HW_RIGHT - GC.HW_LEFT) / float(GC.NUM_FRETS)
	var row_h:  float = GC.string_row_h()
	var hw: float = maxf(3.0, (fret_w * 0.44) * scale)
	var hh: float = maxf(2.0, (row_h  * 0.38) * scale)
	# Sustain tail
	if sus > 0.05:
		var tth_end: float = (t + sus) - playback
		if tth_end > -0.3:
			var depth_end: float   = GC.depth_for_tth(tth_end)
			var pos_end:   Vector2 = GC.project(cx, cy, depth_end)
			draw_line(pos_end, pos, col.darkened(0.35), maxf(2.0, hh * 0.7))
	# Note body
	if fret == 0:
		var r: float = hw * 0.7
		draw_circle(pos, r, Color(col.r, col.g, col.b, 0.22))
		draw_arc(pos, r, 0, TAU, 36, col, maxf(1.0, 1.8 * scale))
	else:
		var rect := Rect2(pos.x - hw, pos.y - hh, hw * 2.0, hh * 2.0)
		draw_rect(rect, col.darkened(0.10))
		draw_rect(rect, col.lightened(0.50), false, maxf(0.8, 1.4 * scale))
		draw_line(
			Vector2(rect.position.x + 1, rect.position.y + 1),
			Vector2(rect.end.x - 1,      rect.position.y + 1),
			Color(1, 1, 1, 0.45 * scale), maxf(0.8, 1.8 * scale))
		if scale > 0.28:
			var fs: int = int(maxf(7.0, hw * 0.90))
			draw_string(ThemeDB.fallback_font,
				pos + Vector2(-hw * 0.5, hh * 0.42),
				str(fret), HORIZONTAL_ALIGNMENT_CENTER,
				int(hw * 2.2), fs, Color.WHITE)
