extends Node3D

const TRACK_WIDTH := 14.0

# Centerline control points (x, z) of the closed circuit; smoothed into a
# Curve3D. Start/finish is at the first point, driving toward the second.
const TRACK_POINTS: Array[Vector2] = [
	Vector2(-80, 100), Vector2(40, 100),    # main straight
	Vector2(100, 70), Vector2(115, 10),     # turn 1, sweeping right
	Vector2(75, -35), Vector2(95, -95),     # esses
	Vector2(25, -110),                      # bottom sweeper
	Vector2(-25, -65),                      # chicane
	Vector2(-75, -105),                     # dip
	Vector2(-125, -65),                     # far hairpin
	Vector2(-95, -5),                       # inward kink
	Vector2(-125, 55),                      # final left sweeper
]

var car: Car
var hud: Hud
var _curve := Curve3D.new()
var _centerline: PackedVector3Array = []

func _ready() -> void:
	_build_curve()
	_build_environment()
	_build_track()
	_build_scenery()
	_build_checkpoints()
	_spawn_car()
	_spawn_hud()
	_start_countdown()

func _build_curve() -> void:
	# Catmull-Rom style tangents from neighbours; the first point is repeated
	# at the end so the loop closes seamlessly.
	var n := TRACK_POINTS.size()
	for i in n + 1:
		var p := TRACK_POINTS[i % n]
		var prev := TRACK_POINTS[(i - 1 + n) % n]
		var next := TRACK_POINTS[(i + 1) % n]
		var tangent := (next - prev) * 0.25
		var t3 := Vector3(tangent.x, 0, tangent.y)
		_curve.add_point(Vector3(p.x, 0, p.y), -t3, t3)
	_curve.bake_interval = 1.0
	for i in int(_curve.get_baked_length() / 5.0):
		_centerline.append(_curve.sample_baked(i * 5.0))

func _track_transform(offset: float) -> Transform3D:
	var length := _curve.get_baked_length()
	offset = fposmod(offset, length)
	var pos := _curve.sample_baked(offset)
	var ahead := _curve.sample_baked(fposmod(offset + 0.5, length))
	var dir := ahead - pos
	dir.y = 0.0
	dir = dir.normalized()
	return Transform3D(Basis.looking_at(dir, Vector3.UP), pos)

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.75)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.2)
	sky_mat.ground_horizon_color = Color(0.65, 0.75, 0.8)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.9)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var ground := StaticBody3D.new()
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(600, 1, 600)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_col)

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.45, 0.2)
	grass_mat.roughness = 1.0
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground_mesh.mesh = plane
	ground_mesh.material_override = grass_mat
	ground.add_child(ground_mesh)
	add_child(ground)

func _build_track() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.16, 0.16, 0.18)
	asphalt.roughness = 0.95

	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = Color(0.85, 0.87, 0.9)
	barrier_mat.roughness = 0.6

	var curb_red := StandardMaterial3D.new()
	curb_red.albedo_color = Color(0.8, 0.1, 0.1)

	var step := 3.0
	# Generous overlap so segments fanning around the outside of a corner
	# don't leave gaps.
	var seg_mesh := BoxMesh.new()
	seg_mesh.size = Vector3(TRACK_WIDTH, 0.1, step + 2.5)
	var curb_mesh := BoxMesh.new()
	curb_mesh.size = Vector3(0.7, 0.14, step + 2.5)
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.5, 1.2, step + 3.5)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = wall_shape.size

	var count := int(_curve.get_baked_length() / step) + 1
	for i in count:
		var xf := _track_transform(i * step)
		var right := xf.basis.x

		var seg := MeshInstance3D.new()
		seg.mesh = seg_mesh
		seg.material_override = asphalt
		seg.basis = xf.basis
		seg.position = xf.origin + Vector3(0, 0.06, 0)
		add_child(seg)

		for side: float in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			curb.mesh = curb_mesh
			curb.material_override = curb_red
			curb.basis = xf.basis
			curb.position = xf.origin + right * side * (TRACK_WIDTH / 2.0 - 0.35) \
				+ Vector3(0, 0.08, 0)
			add_child(curb)

			var wall := StaticBody3D.new()
			wall.basis = xf.basis
			wall.position = xf.origin + right * side * (TRACK_WIDTH / 2.0 + 1.5) \
				+ Vector3(0, 0.6, 0)

			var wall_col := CollisionShape3D.new()
			wall_col.shape = wall_shape
			wall.add_child(wall_col)

			var wall_vis := MeshInstance3D.new()
			wall_vis.mesh = wall_mesh
			wall_vis.material_override = barrier_mat
			wall.add_child(wall_vis)
			add_child(wall)

func _distance_to_track(pos: Vector3) -> float:
	var best := INF
	for p in _centerline:
		best = minf(best, Vector2(p.x, p.z).distance_to(Vector2(pos.x, pos.z)))
	return best

func _build_scenery() -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.28, 0.15)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.12, 0.4, 0.15)
	leaf_mat.roughness = 1.0

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 3.0
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 2.2
	leaf_mesh.height = 4.0

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var placed := 0
	var attempts := 0
	while placed < 60 and attempts < 400:
		attempts += 1
		var pos := Vector3(rng.randf_range(-250, 250), 0, rng.randf_range(-250, 250))
		if _distance_to_track(pos) < TRACK_WIDTH / 2.0 + 6.0:
			continue
		placed += 1
		var scale_factor := rng.randf_range(0.8, 1.6)

		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position = pos + Vector3(0, 1.5 * scale_factor, 0)
		trunk.scale = Vector3.ONE * scale_factor
		add_child(trunk)

		var leaves := MeshInstance3D.new()
		leaves.mesh = leaf_mesh
		leaves.material_override = leaf_mat
		leaves.position = pos + Vector3(0, 4.2 * scale_factor, 0)
		leaves.scale = Vector3.ONE * scale_factor
		add_child(leaves)

func _build_checkpoints() -> void:
	var checkpoint_script := load("res://scripts/checkpoint.gd")
	var length := _curve.get_baked_length()
	for i in RaceManager.NUM_CHECKPOINTS:
		var xf := _track_transform(length * i / RaceManager.NUM_CHECKPOINTS)
		var checkpoint := Area3D.new()
		checkpoint.set_script(checkpoint_script)
		checkpoint.checkpoint_index = i
		checkpoint.basis = xf.basis
		checkpoint.position = xf.origin + Vector3(0, 2, 0)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(TRACK_WIDTH, 4.0, 1.0)
		col.shape = shape
		checkpoint.add_child(col)
		add_child(checkpoint)

		if i == 0:
			_build_start_line(checkpoint)

func _build_start_line(parent: Node3D) -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.05)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)

	var cols := 14
	var tile_size := TRACK_WIDTH / cols
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(tile_size, 0.05, tile_size)
	for row in 2:
		for c in cols:
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.material_override = white if (row + c) % 2 == 0 else black
			tile.position = Vector3(
				-TRACK_WIDTH / 2.0 + tile_size * (c + 0.5),
				-1.88,
				(row - 0.5) * tile_size)
			parent.add_child(tile)

func _spawn_car() -> void:
	car = preload("res://scenes/car.tscn").instantiate()
	# A few metres past the start line, nose along the track.
	var xf := _track_transform(5.0)
	car.basis = xf.basis
	car.position = xf.origin + Vector3(0, 0.7, 0)
	add_child(car)

func _spawn_hud() -> void:
	hud = preload("res://scenes/hud.tscn").instantiate()
	add_child(hud)

func _start_countdown() -> void:
	car.set_physics_process(false)
	for n in [3, 2, 1]:
		hud.show_message(str(n))
		await get_tree().create_timer(1.0).timeout
	hud.show_message("GO!")
	car.set_physics_process(true)
	RaceManager.start_race()
	await get_tree().create_timer(1.0).timeout
	hud.hide_message()
