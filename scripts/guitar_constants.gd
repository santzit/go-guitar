## GuitarConstants -- shared 3D world constants and helpers (Node3D scene).
##
## 3D Coordinate System (Highland-design wiki spec):
##   X = lane position  (lane_x(vis) = (vis - 2.5) * LANE_SPACING, centered at 0)
##   Y = height above highway surface (0 = surface level)
##   Z = depth  (hit zone = Z=0, notes spawn at Z=-HIGHWAY_LENGTH and approach Z=0)
##
## Include via:  const GC = preload("res://scripts/guitar_constants.gd")

# ── Timing (Highland-design wiki defaults) ─────────────────────────────────────
const LOOKAHEAD_S    := 3.0    ## seconds of notes visible ahead (wiki default: 3.0)
const HIGHWAY_SPEED  := 8.0    ## units per second (wiki default: 8.0)
const HIGHWAY_LENGTH := 24.0   ## = HIGHWAY_SPEED * LOOKAHEAD_S (wiki default: 24.0)
const LOOK_AHEAD     := LOOKAHEAD_S   ## alias kept for backward compatibility
const LOOK_DEPTH     := HIGHWAY_LENGTH  ## alias kept for backward compatibility
const FINGER_PREVIEW := 1.5    ## seconds before hit to show finger indicator

# ── Hit window ─────────────────────────────────────────────────────────────────
const HIT_EARLY_MS := 80
const HIT_LATE_MS  := 80

# ── Guitar dimensions ──────────────────────────────────────────────────────────
const NUM_STRINGS := 6
const NUM_FRETS   := 24

# ── Lane layout (Highland-design wiki) ────────────────────────────────────────
const LANE_SPACING := 0.22     ## units between lane centers (wiki default: 0.22)
const HW_WIDTH     := LANE_SPACING * 5.0   ## = 1.1 units (outermost lane center to center)

# ── Camera ─────────────────────────────────────────────────────────────────────
const CAM_HEIGHT     := 2.0    ## camera Y elevation above highway surface
const CAM_Z_OFFSET   := 1.0    ## camera Z behind the hit zone (positive = behind)
const CAM_LOOK_Y     := 0.0    ## look-at target Y
const CAM_LOOK_Z     := -5.0   ## look-at target Z (deep into the highway)
const CAM_FOV        := 80.0   ## vertical FOV (degrees)
const CAM_LERP_SPEED := 2.5    ## reserved for future camera moves
const CAM_TRACK_PAST := 0.5    ## seconds after note hit that camera still tracks it

# ── Mesh sizing ────────────────────────────────────────────────────────────────
const NOTE_W          := 0.17  ## note box X width  (< LANE_SPACING for visible gaps)
const NOTE_H          := 0.17  ## note box Y height
const NOTE_D          := 0.17  ## note box Z depth
const FRETBOARD_THICK := 0.25  ## fretboard Z thickness (fretboard component only)

# ── Colors ─────────────────────────────────────────────────────────────────────
# Rocksmith 2014 string colours: vis 0=Low E … vis 5=High e
const STRING_COLORS: Array[Color] = [
	Color(0.85, 0.10, 0.10),   # Low E   (vis=0)  red
	Color(1.00, 0.80, 0.00),   # A       (vis=1)  yellow
	Color(0.05, 0.50, 1.00),   # D       (vis=2)  blue
	Color(1.00, 0.40, 0.00),   # G       (vis=3)  orange
	Color(0.10, 0.85, 0.10),   # B       (vis=4)  green
	Color(0.25, 0.90, 1.00),   # High e  (vis=5)  cyan
]

const HW_BG_COLOR    := Color(0.04, 0.05, 0.15, 1.0)   # dark navy highway surface
const LANE_LINE_COL  := Color(0.35, 0.70, 0.95, 0.65)  # light-blue lane divider
const HIT_LINE_COL   := Color(0.95, 0.90, 0.60, 0.90)  # bright yellow-white hit line
const FB_BG_COLOR    := Color(0.08, 0.06, 0.04, 1.0)   # dark wood (fretboard)
const FB_FRET_COLOR  := Color(0.38, 0.32, 0.22, 0.90)  # fret wire color

const DOT_FRETS    := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
const DOUBLE_FRETS := [12, 24]

# ── World-coordinate helpers ───────────────────────────────────────────────────

## X position of string lane for visual index vis.
## vis=0 (Low-E) → -0.55;  vis=5 (High-e) → +0.55  (centered at X=0).
static func lane_x(vis: int) -> float:
	return (float(vis) - 2.5) * LANE_SPACING

## Z position of a note tth seconds before the hit zone.
## tth=0 → z=0 (hit line);  tth=LOOKAHEAD_S → z=-HIGHWAY_LENGTH.
static func note_z(tth: float) -> float:
	return -HIGHWAY_SPEED * clampf(tth, 0.0, LOOKAHEAD_S)

## Convert SNG string_index (0 = High-e) to visual lane index (0 = Low-E).
static func vis_for_si(si: int) -> int:
	return NUM_STRINGS - 1 - clampi(si, 0, NUM_STRINGS - 1)

## 3D X centre of fret f — used by fretboard component only.
static func fret_x(f: int) -> float:
	return float(f) - 0.5

## 3D Y centre of visual string vis — used by fretboard component only.
static func string_y(vis: int) -> float:
	return float(vis) + 0.5

## Camera X — highway is narrow and centered at X=0, so always returns 0.
static func camera_x_for_fret(_active_fret: int) -> float:
	return 0.0
