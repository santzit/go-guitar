## GuitarConstants -- shared constants and projection helpers for the 3D highway.
##
## Include in other scripts via:
##   const GC = preload("res://scripts/guitar_constants.gd")
## Then access as GC.NUM_STRINGS, GC.string_y(vis), etc.
## All members are static; no instance required.

# ── Vanishing point & timing ─────────────────────────────────────────────────
const VP          := Vector2(640, 115)
const HIT_Y       := 572.0
const LOOK_AHEAD  := 5.0
const NUM_STRINGS := 6
const NUM_FRETS   := 24
const FINGER_PREVIEW := 3.0

# ── Highway surface bounds at the hit zone ───────────────────────────────────
const HW_LEFT  := 10.0    # x at fret 0 (nut)
const HW_RIGHT := 1270.0  # x at fret 24

# String rows span a narrow vertical band at the hit zone
const HW_STRING_TOP := 506.0  # y-center of vis=0 (Low E) at hit zone
const HW_STRING_BOT := 566.0  # y-center of vis=5 (High e) at hit zone

# ── Static fretboard strip ───────────────────────────────────────────────────
const FRETBOARD_Y := 582.0
const FRETBOARD_H := 120.0

# ── Colors ───────────────────────────────────────────────────────────────────
# Rocksmith 2014 string colours: vis 0=Low E ... vis 5=High e
const STRING_COLORS: Array[Color] = [
	Color(0.85, 0.10, 0.10),   # Low E   -- red
	Color(1.00, 0.80, 0.00),   # A       -- yellow
	Color(0.05, 0.50, 1.00),   # D       -- blue
	Color(1.00, 0.40, 0.00),   # G       -- orange
	Color(0.10, 0.85, 0.10),   # B       -- green
	Color(0.25, 0.90, 1.00),   # High e  -- cyan
]

const HW_BG       := Color(0.02, 0.03, 0.08, 1.0)
const HIT_COLOR   := Color(1.0,  1.0,  1.0,  0.95)
const FRET_COL    := Color(0.35, 0.70, 0.95, 0.40)
const FB_BG_COLOR := Color(0.07, 0.05, 0.03, 1.0)
const FB_FT_COLOR := Color(0.28, 0.25, 0.18, 1.0)

const DOT_FRETS    := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
const DOUBLE_FRETS := [12, 24]

# ── Static helpers ───────────────────────────────────────────────────────────

## Y-center of string row vis at the hit zone (vis=0=Low E, vis=5=High e).
static func string_y(vis: int) -> float:
	return lerpf(HW_STRING_TOP, HW_STRING_BOT, float(vis) / float(NUM_STRINGS - 1))

## X-position of fret boundary f at the hit zone (0=nut, 24=end).
static func fret_x(f: int) -> float:
	return HW_LEFT + float(f) * (HW_RIGHT - HW_LEFT) / float(NUM_FRETS)

## X-center of fret slot [fret-1...fret] at the hit zone.
static func fret_center_x(fret: int) -> float:
	return (fret_x(fret - 1) + fret_x(fret)) * 0.5

## 3D perspective projection from hit-zone plane to screen.
## depth=0 -> hit zone, depth=1 -> vanishing point.
static func project(fb_x: float, fb_y: float, depth: float) -> Vector2:
	return Vector2(
		lerpf(fb_x, VP.x, depth),
		lerpf(fb_y, VP.y, depth)
	)

## Depth value for a note tth seconds away (clamped 0-1).
static func depth_for_tth(tth: float) -> float:
	return clampf(tth / LOOK_AHEAD, 0.0, 1.0)

## Convert SNG string_index to visual lane (SNG 0=High e -> vis=5; SNG 5=Low E -> vis=0).
static func vis_for_si(si: int) -> int:
	return NUM_STRINGS - 1 - clampi(si, 0, NUM_STRINGS - 1)

## Spacing between string centers at the hit zone.
static func string_row_h() -> float:
	return (HW_STRING_BOT - HW_STRING_TOP) / float(NUM_STRINGS - 1)

## Row height on the static fretboard strip.
static func fb_row_h() -> float:
	return FRETBOARD_H / float(NUM_STRINGS)
