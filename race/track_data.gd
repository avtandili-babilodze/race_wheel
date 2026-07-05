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
	{
		# Nordschleife-inspired: long, narrow-ish loop of relentless esses
		# with one big straight home.
		"name": "Nürburgring",
		"points": [
			Vector2(-30, 150), Vector2(80, 150),    # Döttinger Höhe straight
			Vector2(160, 140), Vector2(200, 95),    # Tiergarten sweep
			Vector2(165, 55), Vector2(205, 10),     # Hatzenbach esses
			Vector2(160, -30), Vector2(195, -80),   # Flugplatz kinks
			Vector2(135, -115),                     # Hohe Acht
			Vector2(85, -85), Vector2(45, -125),    # Brünnchen wiggles
			Vector2(-15, -95), Vector2(-60, -135),  # Pflanzgarten
			Vector2(-120, -105),                    # Bergwerk sweeper
			Vector2(-95, -55),                      # Karussell hook
			Vector2(-150, -20),
			Vector2(-120, 25),                      # Wehrseifen switchback
			Vector2(-185, 60),                      # Breidscheid hairpin
			Vector2(-215, 110),                     # far corner
			Vector2(-150, 145),                     # back onto the straight
		],
	},
	{
		# The endurance monster: a fast outer ring feeding four stacked
		# back-and-forth rungs. Longest lap in the game.
		"name": "Marathon GP",
		"points": [
			Vector2(-140, 190), Vector2(30, 195), Vector2(140, 190),  # front straight
			Vector2(205, 150),                       # turn 1
			Vector2(210, 20), Vector2(208, -95), Vector2(205, -150),  # long right-side blast
			Vector2(150, -195), Vector2(95, -192), Vector2(0, -190), Vector2(-100, -195),  # top straight
			Vector2(-155, -160),                     # drop into the rungs
			Vector2(-60, -120), Vector2(80, -115),   # rung 1, outbound
			Vector2(150, -80),                       # hairpin right
			Vector2(80, -45), Vector2(-60, -45),     # rung 2, back
			Vector2(-132, -58),
			Vector2(-185, -12),                      # hairpin left
			Vector2(-132, 33), Vector2(80, 25),      # rung 3, outbound
			Vector2(150, 60),                        # hairpin right
			Vector2(80, 95), Vector2(-60, 95),       # rung 4, back
			Vector2(-150, 130),                      # sweep home
		],
	},
	{
		# The endurance flagship: a flowing grand-prix layout that uses the
		# whole plot — esses up the east side, a sweeping arc onto the top
		# straight, a wide hairpin, a diagonal blast into a carousel, a
		# western lobe, and a weaving infield run before the line.
		"name": "Colossus",
		"points": [
			Vector2(-185, 342), Vector2(-90, 347), Vector2(60, 349), Vector2(180, 345),  # start/finish straight
			Vector2(285, 325), Vector2(342, 262),    # turn 1, fast right
			Vector2(290, 192), Vector2(347, 123),    # esses climbing the east side
			Vector2(295, 55), Vector2(350, -14),
			Vector2(315, -100), Vector2(350, -190),  # flat-out kinks
			Vector2(298, -272), Vector2(198, -325),  # sweeping arc onto the top
			Vector2(60, -345), Vector2(-75, -338), Vector2(-168, -352),  # top straight, kinked
			Vector2(-272, -300),                     # wide hairpin
			Vector2(-126, -205), Vector2(-10, -168), # diagonal blast into the infield
			Vector2(95, -200), Vector2(168, -136),   # flick right
			Vector2(184, -58), Vector2(126, 11),     # carousel, long 200° right
			Vector2(37, 21), Vector2(-26, -37),
			Vector2(-136, -63), Vector2(-210, -11),  # ess out to the west
			Vector2(-289, 21), Vector2(-315, 100), Vector2(-257, 158),  # western lobe
			Vector2(-147, 194), Vector2(-32, 147),   # infield weave, outbound
			Vector2(84, 194), Vector2(178, 147),
			Vector2(252, 210),                       # turnaround
			Vector2(158, 278), Vector2(32, 262),     # infield weave, home
			Vector2(-95, 281), Vector2(-185, 264),
			Vector2(-230, 303),                      # final hairpin onto the straight
		],
	},
]
