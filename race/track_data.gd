class_name TrackData

# Smooths a track's control points into a closed Curve2D (Catmull-Rom style
# tangents, first point repeated to close the loop). Used by the menu for
# previews and length display; the race scene builds the same shape in 3D.
static func build_curve2d(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	var n := points.size()
	for i in n + 1:
		var p: Vector2 = points[i % n]
		var prev: Vector2 = points[(i - 1 + n) % n]
		var next: Vector2 = points[(i + 1) % n]
		var tangent := (next - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	curve.bake_interval = 4.0
	return curve

# Each track is a closed circuit defined by centerline control points (x, z),
# smoothed into a curve at build time. Start/finish is at the first point,
# driving toward the second.
const TRACKS := [
	{
		"name": "Grand Circuit",
		"points": [
			Vector2(-80, 100), Vector2(40, 100),    # main straight
			Vector2(100, 70), Vector2(115, 10),     # turn 1, sweeping right
			Vector2(75, -35), Vector2(95, -95),     # esses
			Vector2(25, -110),                      # bottom sweeper
			Vector2(-25, -65),                      # chicane
			Vector2(-75, -105),                     # dip
			Vector2(-125, -65),                     # far hairpin
			Vector2(-95, -5),                       # inward kink
			Vector2(-125, 55),                      # final left sweeper
		],
	},
	{
		"name": "Speedway Oval",
		"points": [
			Vector2(-100, 60), Vector2(0, 80), Vector2(100, 60),
			Vector2(130, 0),
			Vector2(100, -60), Vector2(0, -80), Vector2(-100, -60),
			Vector2(-130, 0),
		],
	},
	{
		"name": "Switchback Snake",
		"points": [
			Vector2(-120, 80), Vector2(60, 80),     # top straight
			Vector2(110, 50), Vector2(60, 20),      # hairpin right
			Vector2(-60, 20),                       # middle straight back
			Vector2(-110, -10), Vector2(-60, -40),  # hairpin left
			Vector2(60, -40),                       # middle straight out
			Vector2(110, -70), Vector2(30, -100),   # hairpin right low
			Vector2(-100, -100),                    # bottom straight
			Vector2(-155, -60), Vector2(-155, 30),  # left side climb
		],
	},
]
