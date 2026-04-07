## GuitarConstants -- shared 3D world constants and helpers (Node3D scene).
##
## 3D Coordinate System:
##   X = fret position  (fret f center = f - 0.5;  fret 1 = 0.5, fret 24 = 23.5)
##   Y = string position (vis=0 Low-E at Y=0.5, vis=5 High-e at Y=5.5)
##   Z = depth           (hit zone = Z=0, notes approach from Z < 0)
##
## Include via:  const GC = preload("res://scripts/guitar_constants.gd")

# ── Timing ──────────────────────────────────────────────────────────────────
const LOOK_AHEAD     := 5.0    ## seconds of notes shown ahead
const LOOK_DEPTH     := 14.0   ## 3D world units from hit zone to note spawn
const FINGER_PREVIEW := 2.0    ## seconds before hit to show finger indicator

# ── Guitar dimensions ────────────────────────────────────────────────────────
const NUM_STRINGS := 6
const NUM_FRETS   := 24

# ── Camera ───────────────────────────────────────────────────────────────────
const CAM_HEIGHT     := 5.5    ## camera Y elevation
const CAM_Z_OFFSET   := 7.0    ## camera Z behind hit zone
const CAM_LOOK_Y     := 2.5    ## look-at target Y (vertical centre of strings)
const CAM_LOOK_Z     := -5.0   ## look-at target Z
const CAM_FOV        := 45.0   ## vertical FOV (degrees) — shows ~6 frets wide
const CAM_LERP_SPEED := 2.5    ## camera X smooth-follow speed

# ── Mesh sizing ───────────────────────────────────────────────────────────────
const NOTE_W          := 0.42  ## note box width  (fraction of 1-unit fret slot)
const NOTE_H          := 0.30  ## note box height (fraction of 1-unit string row)
const LANE_LINE_W     := 0.04  ## fret-depth-divider line thickness
const FRETBOARD_THICK := 0.25  ## fretboard box depth in Z

# ── Colors ───────────────────────────────────────────────────────────────────
# Rocksmith 2014 string colours: vis 0=Low E … vis 5=High e
const STRING_COLORS: Array[Color] = [
	Color(0.85, 0.10, 0.10),   # Low E   (vis=0)  red
	Color(1.00, 0.80, 0.00),   # A       (vis=1)  yellow
	Color(0.05, 0.50, 1.00),   # D       (vis=2)  blue
	Color(1.00, 0.40, 0.00),   # G       (vis=3)  orange
	Color(0.10, 0.85, 0.10),   # B       (vis=4)  green
	Color(0.25, 0.90, 1.00),   # High e  (vis=5)  cyan
]

const HW_BG_COLOR    := Color(0.02, 0.03, 0.10, 1.0)   # dark navy
const FRET_LINE_COL  := Color(0.35, 0.70, 0.95, 0.55)  # light-blue depth divider
const FB_BG_COLOR    := Color(0.08, 0.06, 0.04, 1.0)   # dark wood
const FB_FRET_COLOR  := Color(0.38, 0.32, 0.22, 0.90)  # fret wire

const DOT_FRETS    := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
const DOUBLE_FRETS := [12, 24]

# ── World-coordinate helpers ─────────────────────────────────────────────────

## 3D X centre of fret f  (fret 1 → 0.5,  fret 24 → 23.5).
static func fret_x(f: int) -> float:
	return float(f) - 0.5

## 3D Y centre of visual string vis  (vis=0 Low-E → 0.5,  vis=5 High-e → 5.5).
static func string_y(vis: int) -> float:
	return float(vis) + 0.5

## 3D Z position of a note tth seconds before the hit zone.
static func note_z(tth: float) -> float:
	return -clampf(tth, 0.0, LOOK_AHEAD) * (LOOK_DEPTH / LOOK_AHEAD)

## Convert SNG string_index (0 = High-e) to visual lane (0 = Low-E).
static func vis_for_si(si: int) -> int:
	return NUM_STRINGS - 1 - clampi(si, 0, NUM_STRINGS - 1)

## Camera X to centre on the given active fret (clamped to stay on fretboard).
static func camera_x_for_fret(active_fret: int) -> float:
	var cx: float = fret_x(active_fret)
	return clampf(cx, 3.5, float(NUM_FRETS) - 3.5)
