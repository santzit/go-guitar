## HighwayGrid -- 24-fret x 6-string 3D perspective highway grid.
## Pure visual component: no note data, no runtime state.
extends Node2D

const GC = preload("res://scripts/guitar_constants.gd")


func _draw() -> void:
	_draw_background()
	_draw_highway_surface()
	_draw_string_lanes()
	_draw_fret_dividers()
	_draw_depth_markers()
	_draw_hit_zone()


func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 1280, GC.FRETBOARD_Y), GC.HW_BG)


func _draw_highway_surface() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(GC.VP.x, GC.VP.y),
			Vector2(GC.VP.x, GC.VP.y),
			Vector2(GC.HW_RIGHT, GC.HIT_Y),
			Vector2(GC.HW_LEFT,  GC.HIT_Y),
		]),
		Color(0.04, 0.06, 0.14, 1.0)
	)


func _draw_string_lanes() -> void:
	var row_h: float = GC.string_row_h()
	for vis in range(GC.NUM_STRINGS):
		var sy_mid: float = GC.string_y(vis)
		var sy_bot: float = sy_mid + row_h * 0.5
		var col: Color = GC.STRING_COLORS[vis]
		# Faint colored band
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(GC.VP.x,      GC.VP.y),
				Vector2(GC.VP.x,      GC.VP.y),
				Vector2(GC.HW_RIGHT,  sy_bot),
				Vector2(GC.HW_LEFT,   sy_bot),
			]),
			Color(col.r, col.g, col.b, 0.06)
		)
		# String wire: two converging lines toward VP
		draw_line(Vector2(GC.HW_LEFT,  sy_mid), Vector2(GC.VP.x, GC.VP.y),
			Color(col.r, col.g, col.b, 0.70), 1.5)
		draw_line(Vector2(GC.HW_RIGHT, sy_mid), Vector2(GC.VP.x, GC.VP.y),
			Color(col.r, col.g, col.b, 0.70), 1.5)
	# Outer border lines
	var border_col := Color(0.35, 0.70, 0.95, 0.35)
	draw_line(Vector2(GC.HW_LEFT,  GC.HW_STRING_TOP - 8), Vector2(GC.VP.x, GC.VP.y), border_col, 1.0)
	draw_line(Vector2(GC.HW_RIGHT, GC.HW_STRING_TOP - 8), Vector2(GC.VP.x, GC.VP.y), border_col, 1.0)
	draw_line(Vector2(GC.HW_LEFT,  GC.HW_STRING_BOT + 8), Vector2(GC.VP.x, GC.VP.y), border_col, 1.0)
	draw_line(Vector2(GC.HW_RIGHT, GC.HW_STRING_BOT + 8), Vector2(GC.VP.x, GC.VP.y), border_col, 1.0)


func _draw_fret_dividers() -> void:
	var string_top: float = GC.HW_STRING_TOP - 8.0
	var string_bot: float = GC.HW_STRING_BOT + 8.0
	for f in range(GC.NUM_FRETS + 1):
		var fx: float = GC.fret_x(f)
		var is_oct: bool = (f == 0 or f == 12 or f == 24)
		var alpha: float = 0.55 if is_oct else 0.22
		var width: float = 1.4 if is_oct else 0.7
		draw_line(Vector2(fx, string_top), Vector2(GC.VP.x, GC.VP.y),
			Color(GC.FRET_COL.r, GC.FRET_COL.g, GC.FRET_COL.b, alpha), width)
		draw_line(Vector2(fx, string_bot), Vector2(GC.VP.x, GC.VP.y),
			Color(GC.FRET_COL.r, GC.FRET_COL.g, GC.FRET_COL.b, alpha * 0.5), width * 0.6)


func _draw_depth_markers() -> void:
	var num_steps: int = 10
	for step in range(1, num_steps):
		var d: float = float(step) / float(num_steps)
		var alpha: float = lerpf(0.28, 0.04, d)
		var left_x: float  = lerpf(GC.HW_LEFT,  GC.VP.x, d)
		var right_x: float = lerpf(GC.HW_RIGHT, GC.VP.x, d)
		for vis in range(GC.NUM_STRINGS):
			var sy: float = lerpf(GC.string_y(vis), GC.VP.y, d)
			draw_line(Vector2(left_x, sy), Vector2(right_x, sy),
				Color(GC.FRET_COL.r, GC.FRET_COL.g, GC.FRET_COL.b, alpha), 0.5)


func _draw_hit_zone() -> void:
	draw_line(Vector2(0, GC.HIT_Y), Vector2(1280, GC.HIT_Y), GC.HIT_COLOR, 3.0)
	var font := ThemeDB.fallback_font
	for vis in range(GC.NUM_STRINGS):
		var sy: float = GC.string_y(vis)
		var col: Color = GC.STRING_COLORS[vis]
		draw_circle(Vector2(GC.HW_LEFT  - 6.0, sy), 5.0, col)
		draw_circle(Vector2(GC.HW_RIGHT + 6.0, sy), 5.0, col)
	for f: int in [1, 3, 5, 7, 9, 12, 15, 17, 19, 21, 24]:
		var fx: float = GC.fret_center_x(f)
		draw_string(font, Vector2(fx - 5.0, GC.HIT_Y + 14.0),
			str(f), HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
			Color(0.70, 0.70, 0.50, 0.90))
