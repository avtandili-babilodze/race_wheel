extends Node3D

const TRACK_WIDTH := 14.0

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_ESCAPE:
		RaceManager.stop_race()
		get_tree().change_scene_to_file("res://ui/menu/menu.tscn")

func _build_curve() -> void:
	# Catmull-Rom style tangents from neighbours; the first point is repeated
	# at the end so the loop closes seamlessly.
	var points: Array = TrackData.TRACKS[RaceManager.selected_track].points
	var n := points.size()
	for i in n + 1:
		var p: Vector2 = points[i % n]
		var prev: Vector2 = points[(i - 1 + n) % n]
		var next: Vector2 = points[(i + 1) % n]
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
	asphalt.cull_mode = BaseMaterial3D.CULL_DISABLED

	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = Color(0.85, 0.87, 0.9)
	barrier_mat.roughness = 0.6
	barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var curb_red := StandardMaterial3D.new()
	curb_red.albedo_color = Color(0.8, 0.1, 0.1)
	curb_red.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Sample the whole loop at even intervals; the last sample wraps back to
	# offset 0 so every ribbon closes seamlessly.
	var length := _curve.get_baked_length()
	var count := int(ceil(length / 2.0))
	var xfs: Array[Transform3D] = []
	for i in count + 1:
		xfs.append(_track_transform(length * i / count))

	var half := TRACK_WIDTH / 2.0
	_add_ribbon(_strip(_rail(xfs, -half, 0.1), _rail(xfs, half, 0.1)), asphalt)
	for side: float in [-1.0, 1.0]:
		_add_ribbon(_strip(
			_rail(xfs, side * (half - 0.7), 0.12),
			_rail(xfs, side * half, 0.12)), curb_red)

	# Walls: inner face, outer face, and top cap per side, all one strip
	# family, plus a single trimesh collider for everything.
	var wall_tris := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var b_in := side * (half + 1.25)
		var b_out := side * (half + 1.75)
		var faces := _strip(_rail(xfs, b_in, 0.0), _rail(xfs, b_in, 1.2))
		faces.append_array(_strip(_rail(xfs, b_out, 0.0), _rail(xfs, b_out, 1.2)))
		faces.append_array(_strip(_rail(xfs, b_in, 1.2), _rail(xfs, b_out, 1.2)))
		_add_ribbon(faces, barrier_mat)
		wall_tris.append_array(faces)

	var wall_body := StaticBody3D.new()
	var wall_col := CollisionShape3D.new()
	var wall_shape := ConcavePolygonShape3D.new()
	wall_shape.set_faces(wall_tris)
	wall_shape.backface_collision = true
	wall_col.shape = wall_shape
	wall_body.add_child(wall_col)
	add_child(wall_body)

func _rail(xfs: Array[Transform3D], lateral: float, height: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for xf in xfs:
		pts.append(xf.origin + xf.basis.x * lateral + Vector3.UP * height)
	return pts

func _strip(a: PackedVector3Array, b: PackedVector3Array) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for i in a.size() - 1:
		tris.append_array([a[i], b[i], b[i + 1], a[i], b[i + 1], a[i + 1]])
	return tris

func _add_ribbon(tris: PackedVector3Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in tris:
		st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)

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
	var checkpoint_script := load("res://race/checkpoint.gd")
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
	car = preload("res://car/car.tscn").instantiate()
	# A few metres past the start line, nose along the track.
	var xf := _track_transform(5.0)
	car.basis = xf.basis
	car.position = xf.origin + Vector3(0, 0.7, 0)
	add_child(car)

func _spawn_hud() -> void:
	hud = preload("res://ui/hud/hud.tscn").instantiate()
	hud.car = car
	add_child(hud)

func _start_countdown() -> void:
	car.set_physics_process(false)
	for n in [3, 2, 1]:
		hud.show_message(str(n))
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(hud):
			return  # scene was exited mid-countdown
	hud.show_message("GO!")
	car.set_physics_process(true)
	RaceManager.start_race()
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(hud):
		hud.hide_message()
