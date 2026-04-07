## GuitarConstants -- shared 3D world constants and helpers.
##
## 3D Coordinate System (Guitar Hero / Rocksmith style flat highway):
##   X = string lane   (lane_x(vis);  Low-E = 0.0 … High-e = 5.0)
##   Y = height        (highway surface at Y=0; notes sit at Y=NOTE_Y)
##   Z = time depth    (hit zone = Z=0; notes spawn far at Z=-HIGHWAY_LENGTH
##                      and travel toward the player at Z=0)
##
## The highway is 6 lanes wide (one per string) and HIGHWAY_LENGTH units deep.
## Camera is fixed above and behind the hit zone, looking down the highway.
##
## Include via:  const GC = preload("res://scripts/guitar_constants.gd")

# ── Timing ─────────────────────────────────────────────────────────────────────
const LOOKAHEAD_S    := 3.0    ## seconds of notes visible ahead
const HIGHWAY_SPEED  := 8.0    ## units per second
const HIGHWAY_LENGTH := 24.0   ## = HIGHWAY_SPEED * LOOKAHEAD_S
const LOOK_AHEAD     := LOOKAHEAD_S
const LOOK_DEPTH     := HIGHWAY_LENGTH
const FINGER_PREVIEW := 1.5    ## seconds before hit to show finger indicator

# ── Hit window ─────────────────────────────────────────────────────────────────
const HIT_EARLY_MS := 80
const HIT_LATE_MS  := 80

# ── Guitar dimensions ──────────────────────────────────────────────────────────
const NUM_STRINGS := 6
const NUM_FRETS   := 24

# ── World spacing ──────────────────────────────────────────────────────────────
const LANE_SPACING   := 1.0    ## 1 unit between lane centres
const HIGHWAY_WIDTH  := float(NUM_STRINGS - 1) * LANE_SPACING  ## = 5.0 (edge-to-edge centre)
const LANE_PADDING   := 0.55   ## padding beyond outermost lane centres on each side

# ── Note geometry ──────────────────────────────────────────────────────────────
const NOTE_W := 0.75   ## note box X width  (fits inside 1-unit lane)
const NOTE_H := 0.18   ## note box Y height (flat disc sitting on surface)
const NOTE_D := 0.60   ## note box Z depth  (travel direction)
const NOTE_Y := 0.09   ## note centre height above surface (= NOTE_H / 2)

# ── Camera (fixed above the hit zone, looking down the highway) ────────────────
const CAM_HEIGHT    := 3.5    ## Y elevation above highway surface
const CAM_Z_OFFSET  := 6.0    ## Z behind the hit zone (positive = behind player)
const CAM_LOOK_Y    := 0.0    ## look-at target Y (surface level)
const CAM_LOOK_Z    := -12.0  ## look-at target Z (deep into highway)
const CAM_FOV       := 70.0   ## vertical FOV (degrees)
const CAM_X         := HIGHWAY_WIDTH * 0.5   ## = 2.5, fixed centre of all lanes
const CAM_LERP_SPEED := 2.5   ## kept for API compatibility
const CAM_TRACK_PAST := 0.5

# ── Colors ─────────────────────────────────────────────────────────────────────
# String colours: vis 0=Low E … vis 5=High e
const STRING_COLORS: Array[Color] = [
	Color(0.85, 0.10, 0.10),   # Low E   (vis=0)  red
	Color(1.00, 0.80, 0.00),   # A       (vis=1)  yellow
	Color(0.05, 0.50, 1.00),   # D       (vis=2)  blue
	Color(1.00, 0.40, 0.00),   # G       (vis=3)  orange
	Color(0.10, 0.85, 0.10),   # B       (vis=4)  green
	Color(0.25, 0.90, 1.00),   # High e  (vis=5)  cyan
]

const HW_BG_COLOR   := Color(0.04, 0.05, 0.15, 1.0)   # dark navy highway surface
const LANE_LINE_COL := Color(0.35, 0.70, 0.95, 0.65)  # light-blue lane divider
const HIT_LINE_COL  := Color(0.95, 0.90, 0.60, 0.90)  # bright yellow-white hit line

const DOT_FRETS    := [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
const DOUBLE_FRETS := [12, 24]

# ── World-coordinate helpers ───────────────────────────────────────────────────

## X centre of string lane vis in world space.
## vis=0 (Low-E) → X=0.0;  vis=5 (High-e) → X=5.0.
static func lane_x(vis: int) -> float:
	return float(vis) * LANE_SPACING

## Z position of a note tth seconds before the hit zone.
## tth=0 → z=0 (hit line);  tth=LOOKAHEAD_S → z=-HIGHWAY_LENGTH.
static func note_z(tth: float) -> float:
	return -HIGHWAY_SPEED * clampf(tth, 0.0, LOOKAHEAD_S)

## Convert SNG string_index (0 = High-e) to visual lane index (0 = Low-E).
static func vis_for_si(si: int) -> int:
	return NUM_STRINGS - 1 - clampi(si, 0, NUM_STRINGS - 1)
