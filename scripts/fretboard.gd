## Fretboard -- static 24-fret x 6-string strip with finger-indicator dots.
extends Node2D

const GC = preload("res://scripts/guitar_constants.gd")

var notes:    Array = []
var playback: float = 0.0


func _draw() -> void:
	_draw_wood_background()
	_draw_fret_wires()
	_draw_string_lines()
	_draw_inlay_dots()
	_draw_fret_labels()
	_draw_finger_dots()


func _draw_wood_background() -> void:
	draw_rect(Rect2(0, GC.FRETBOARD_Y, 1280, GC.FRETBOARD_H), GC.FB_BG_COLOR)
	var rh: float = GC.fb_row_h()
	for vis in range(GC.NUM_STRINGS + 1):
		var y: float = GC.FRETBOARD_Y + vis * rh
		draw_line(Vector2(0, y), Vector2(1280, y),
			Color(0.15, 0.12, 0.08, 0.35), 0.6)


func _draw_fret_wires() -> void:
	for f in range(GC.NUM_FRETS + 1):
		var fx: float = GC.fret_x(f)
		var is_oct: bool = (f == 0 or f == 12 or f == 24)
		var alpha: float = 0.80 if is_oct else 0.45
		var width: float = 2.0 if is_oct else 1.2
		draw_line(
			Vector2(fx, GC.FRETBOARD_Y),
			Vector2(fx, GC.FRETBOARD_Y + GC.FRETBOARD_H),
			Color(GC.FB_FT_COLOR.r, GC.FB_FT_COLOR.g, GC.FB_FT_COLOR.b, alpha),
			width)


func _draw_string_lines() -> void:
	var rh: float = GC.fb_row_h()
	for vis in range(GC.NUM_STRINGS):
		var sy: float  = GC.FRETBOARD_Y + (vis + 0.5) * rh
		var col: Color = GC.STRING_COLORS[vis]
		draw_line(Vector2(0, sy), Vector2(1280, sy),
			Color(col.r, col.g, col.b, 0.55), 1.4)


func _draw_inlay_dots() -> void:
	var rh: float = GC.fb_row_h()
	for f: int in GC.DOT_FRETS:
		var fx: float = GC.fret_center_x(f)
		if f in GC.DOUBLE_FRETS:
			draw_circle(Vector2(fx, GC.FRETBOARD_Y + rh * 1.5), 4.0, Color(0.70, 0.70, 0.50, 0.85))
			draw_circle(Vector2(fx, GC.FRETBOARD_Y + rh * 4.5), 4.0, Color(0.70, 0.70, 0.50, 0.85))
		else:
			draw_circle(Vector2(fx, GC.FRETBOARD_Y + GC.FRETBOARD_H * 0.50), 4.0,
				Color(0.70, 0.70, 0.50, 0.85))


func _draw_fret_labels() -> void:
	var font := ThemeDB.fallback_font
	for f: int in [1, 3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var fx: float = GC.fret_center_x(f)
		draw_string(font, Vector2(fx - 5.0, GC.FRETBOARD_Y + GC.FRETBOARD_H - 4.0),
			str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.70, 0.70, 0.50, 0.80))


func _draw_finger_dots() -> void:
	var rh: float = GC.fb_row_h()
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
	var font := ThemeDB.fallback_font
	for si in range(GC.NUM_STRINGS):
		var nv: Variant = nearest[si]
		if nv == null:
			continue
		var fret: int   = int(nv["fret"])
		var vis:  int   = GC.vis_for_si(si)
		var fx:   float = GC.fret_center_x(fret)
		var fy:   float = GC.FRETBOARD_Y + (vis + 0.5) * rh
		var col:  Color = GC.STRING_COLORS[vis]
		var dot_r: float = minf(rh * 0.40, 9.5)
		draw_circle(Vector2(fx, fy), dot_r + 2.5, Color(0.0, 0.0, 0.0, 0.60))
		draw_circle(Vector2(fx, fy), dot_r, col)
		var fs: int = maxi(7, int(dot_r * 1.2))
		draw_string(font, Vector2(fx - dot_r, fy - fs * 0.5),
			str(fret), HORIZONTAL_ALIGNMENT_CENTER,
			int(dot_r * 2.0), fs, Color.WHITE)
