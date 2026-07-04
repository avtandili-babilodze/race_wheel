extends Node3D

const TRACK_WIDTH := 14.0

var car: Car
var hud: Hud
var _curve := Curve3D.new()
var _centerline: PackedVector3Array = []
var _stand_spots: PackedVector3Array = []

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

func _noise_tex(freq: float, dark: Color, light: Color) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = freq
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	tex.color_ramp = ramp
	return tex

func _build_environment() -> void:
	# Late-afternoon sun: warm, low-ish, long soft shadows.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.74)
	sky_mat.sky_horizon_color = Color(0.7, 0.78, 0.87)
	sky_mat.ground_bottom_color = Color(0.18, 0.26, 0.2)
	sky_mat.ground_horizon_color = Color(0.66, 0.74, 0.82)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.88)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var ground := StaticBody3D.new()
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(800, 1, 800)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_col)

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_texture = _noise_tex(
		0.01, Color(0.16, 0.32, 0.13), Color(0.25, 0.44, 0.18))
	grass_mat.uv1_scale = Vector3(60, 60, 1)
	grass_mat.roughness = 1.0
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	ground_mesh.mesh = plane
	ground_mesh.material_override = grass_mat
	ground.add_child(ground_mesh)
	add_child(ground)

func _build_track() -> void:
	var length := _curve.get_baked_length()
	var count := int(ceil(length / 2.0))
	var xfs: Array[Transform3D] = []
	for i in count + 1:
		xfs.append(_track_transform(length * i / count))

	var half := TRACK_WIDTH / 2.0

	# Asphalt with subtle noise grain, UV-mapped along the track.
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = _noise_tex(
		0.05, Color(0.13, 0.13, 0.15), Color(0.2, 0.2, 0.23))
	asphalt.roughness = 0.9
	asphalt.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_road(xfs, asphalt)

	var line_white := StandardMaterial3D.new()
	line_white.albedo_color = Color(0.92, 0.92, 0.9)
	line_white.roughness = 0.7
	line_white.cull_mode = BaseMaterial3D.CULL_DISABLED

	var curb_red := StandardMaterial3D.new()
	curb_red.albedo_color = Color(0.75, 0.09, 0.07)
	curb_red.roughness = 0.75
	curb_red.cull_mode = BaseMaterial3D.CULL_DISABLED

	for side: float in [-1.0, 1.0]:
		# Solid white edge line just inside the curb.
		_add_ribbon(_strip(
			_rail(xfs, side * (half - 1.05), 0.105),
			_rail(xfs, side * (half - 0.85), 0.105)), line_white)
		# Red curb strip at the track edge.
		_add_ribbon(_strip(
			_rail(xfs, side * (half - 0.7), 0.12),
			_rail(xfs, side * half, 0.12)), curb_red)

	_add_dashes(line_white)

	# Walls: white faces with a red top cap; one trimesh collider for all.
	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = Color(0.88, 0.89, 0.92)
	barrier_mat.roughness = 0.55
	barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var cap_red := StandardMaterial3D.new()
	cap_red.albedo_color = Color(0.72, 0.1, 0.08)
	cap_red.roughness = 0.6
	cap_red.cull_mode = BaseMaterial3D.CULL_DISABLED

	var wall_tris := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var b_in := side * (half + 1.25)
		var b_out := side * (half + 1.75)
		var faces := _strip(_rail(xfs, b_in, 0.0), _rail(xfs, b_in, 1.2))
		faces.append_array(_strip(_rail(xfs, b_out, 0.0), _rail(xfs, b_out, 1.2)))
		_add_ribbon(faces, barrier_mat)
		var cap := _strip(_rail(xfs, b_in, 1.2), _rail(xfs, b_out, 1.2))
		_add_ribbon(cap, cap_red)
		wall_tris.append_array(faces)
		wall_tris.append_array(cap)

	var wall_body := StaticBody3D.new()
	var wall_col := CollisionShape3D.new()
	var wall_shape := ConcavePolygonShape3D.new()
	wall_shape.set_faces(wall_tris)
	wall_shape.backface_collision = true
	wall_col.shape = wall_shape
	wall_body.add_child(wall_col)
	add_child(wall_body)

	_build_gantry()

func _add_road(xfs: Array[Transform3D], mat: Material) -> void:
	# The road strip carries UVs (u across, v along) so the asphalt
	# grain tiles down the track instead of stretching.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := TRACK_WIDTH / 2.0
	var prev_a := Vector3.ZERO
	var prev_b := Vector3.ZERO
	var prev_v := 0.0
	for i in xfs.size():
		var a := xfs[i].origin - xfs[i].basis.x * half + Vector3.UP * 0.1
		var b := xfs[i].origin + xfs[i].basis.x * half + Vector3.UP * 0.1
		var v := prev_v
		if i > 0:
			v = prev_v + xfs[i].origin.distance_to(xfs[i - 1].origin) / 7.0
			st.set_uv(Vector2(0, prev_v))
			st.add_vertex(prev_a)
			st.set_uv(Vector2(2, prev_v))
			st.add_vertex(prev_b)
			st.set_uv(Vector2(2, v))
			st.add_vertex(b)
			st.set_uv(Vector2(0, prev_v))
			st.add_vertex(prev_a)
			st.set_uv(Vector2(2, v))
			st.add_vertex(b)
			st.set_uv(Vector2(0, v))
			st.add_vertex(a)
		prev_a = a
		prev_b = b
		prev_v = v
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)

func _add_dashes(mat: Material) -> void:
	# Dashed center line: 4 m dashes every 10 m, merged into one mesh.
	var tris := PackedVector3Array()
	var length := _curve.get_baked_length()
	var offset := 8.0
	while offset + 4.0 < length:
		var rows_l := PackedVector3Array()
		var rows_r := PackedVector3Array()
		for k in 5:
			var xf := _track_transform(offset + k)
			rows_l.append(xf.origin - xf.basis.x * 0.15 + Vector3.UP * 0.105)
			rows_r.append(xf.origin + xf.basis.x * 0.15 + Vector3.UP * 0.105)
		tris.append_array(_strip(rows_l, rows_r))
		offset += 10.0
	_add_ribbon(tris, mat)

func _build_gantry() -> void:
	# Start/finish arch: two pillars and a checkered banner over the line.
	var xf := _track_transform(0.0)
	var half := TRACK_WIDTH / 2.0

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.85, 0.86, 0.88)
	pillar_mat.metallic = 0.4
	pillar_mat.roughness = 0.4

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.25
	pillar_mesh.bottom_radius = 0.3
	pillar_mesh.height = 6.5
	for side: float in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_mesh
		pillar.material_override = pillar_mat
		pillar.basis = xf.basis
		pillar.position = xf.origin + xf.basis.x * side * (half + 2.3) \
			+ Vector3(0, 3.25, 0)
		add_child(pillar)

	var checker := StandardMaterial3D.new()
	checker.albedo_texture = _checker_tex()
	checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	checker.roughness = 0.8

	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(2 * (half + 2.3) + 0.6, 1.3, 0.5)
	banner.mesh = banner_mesh
	banner.material_override = checker
	banner.basis = xf.basis
	banner.position = xf.origin + Vector3(0, 6.0, 0)
	add_child(banner)

	var sign := Label3D.new()
	sign.text = "RACE WHEEL"
	sign.font_size = 96
	sign.pixel_size = 0.011
	sign.modulate = Color.WHITE
	sign.outline_size = 26
	sign.outline_modulate = Color(0.05, 0.05, 0.08)
	sign.basis = xf.basis
	# Face the cars approaching the line.
	sign.position = xf.origin + Vector3(0, 6.0, 0) + xf.basis.z * 0.27
	add_child(sign)

func _checker_tex() -> ImageTexture:
	var img := Image.create(16, 4, false, Image.FORMAT_RGB8)
	for y in 4:
		for x in 16:
			img.set_pixel(x, y,
				Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.05))
	return ImageTexture.create_from_image(img)

func _crowd_tex() -> NoiseTexture2D:
	# High-frequency cellular noise through a constant multi-colour ramp
	# reads as a crowd of spectators from a distance.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.25
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 64
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.34, 0.5, 0.64, 0.78, 0.9])
	ramp.colors = PackedColorArray([
		Color(0.15, 0.15, 0.18), Color(0.75, 0.15, 0.12), Color(0.15, 0.3, 0.65),
		Color(0.85, 0.75, 0.2), Color(0.85, 0.85, 0.85), Color(0.2, 0.55, 0.25),
		Color(0.8, 0.45, 0.15),
	])
	tex.color_ramp = ramp
	return tex

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
	_build_grandstands()
	_build_mountains()
	_build_trees()

func _build_grandstands() -> void:
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.55, 0.58, 0.62)
	frame_mat.roughness = 0.6

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.9, 0.91, 0.94)
	roof_mat.metallic = 0.3
	roof_mat.roughness = 0.35

	var crowd_mat := StandardMaterial3D.new()
	crowd_mat.albedo_texture = _crowd_tex()
	crowd_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crowd_mat.uv1_scale = Vector3(3, 1, 1)
	crowd_mat.roughness = 1.0

	var lateral := TRACK_WIDTH / 2.0 + 1.75 + 12.0
	for offset: float in [28.0, 62.0]:
		var xf := _track_transform(offset)
		# Pick whichever side has open ground; skip if both are cramped.
		var side := 0.0
		var best_clear := 0.0
		for s: float in [-1.0, 1.0]:
			var p := xf.origin + xf.basis.x * s * lateral
			var clear := _distance_to_track(p)
			if clear > best_clear:
				best_clear = clear
				side = s
		if best_clear < lateral - 3.0:
			continue

		var stand := Node3D.new()
		stand.basis = xf.basis * Basis(Vector3.UP, deg_to_rad(90.0 * side))
		stand.position = xf.origin + xf.basis.x * side * lateral
		add_child(stand)
		_stand_spots.append(stand.position)

		# Tiered steps rising away from the track (stand faces local -Z).
		for s in 6:
			var step := MeshInstance3D.new()
			var step_mesh := BoxMesh.new()
			step_mesh.size = Vector3(18, 0.8 + s * 0.8, 1.5)
			step.mesh = step_mesh
			step.material_override = frame_mat
			step.position = Vector3(0, step_mesh.size.y / 2.0, -3.75 + s * 1.5)
			stand.add_child(step)

			var crowd := MeshInstance3D.new()
			var crowd_mesh := BoxMesh.new()
			crowd_mesh.size = Vector3(18, 0.5, 1.0)
			crowd.mesh = crowd_mesh
			crowd.material_override = crowd_mat
			crowd.position = Vector3(
				0, step_mesh.size.y + 0.25, -3.95 + s * 1.5)
			stand.add_child(crowd)

		var roof := MeshInstance3D.new()
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(19, 0.25, 10.5)
		roof.mesh = roof_mesh
		roof.material_override = roof_mat
		roof.position = Vector3(0, 7.0, 0.4)
		roof.rotation_degrees = Vector3(-6, 0, 0)
		stand.add_child(roof)

		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.12
		post_mesh.bottom_radius = 0.12
		post_mesh.height = 7.0
		for px: float in [-8.5, 8.5]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = frame_mat
			post.position = Vector3(px, 3.5, 3.9)
			stand.add_child(post)

func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.35, 0.33)
	mat.roughness = 1.0
	for i in 14:
		var angle := TAU * i / 14 + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(300.0, 350.0)
		var mountain := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(55.0, 95.0)
		cone.height = rng.randf_range(40.0, 75.0)
		cone.radial_segments = 9
		mountain.mesh = cone
		mountain.material_override = mat
		mountain.position = Vector3(
			cos(angle) * r, cone.height / 2.0 - 2.0, sin(angle) * r)
		mountain.rotation.y = rng.randf() * TAU
		add_child(mountain)

func _build_trees() -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.28, 0.15)
	trunk_mat.roughness = 1.0

	var greens: Array[StandardMaterial3D] = []
	for c in [Color(0.09, 0.29, 0.1), Color(0.14, 0.37, 0.11), Color(0.21, 0.42, 0.14)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		greens.append(m)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 3.0
	var blob_mesh := SphereMesh.new()
	blob_mesh.radius = 1.8
	blob_mesh.height = 3.2
	var pine_mesh := CylinderMesh.new()
	pine_mesh.top_radius = 0.0
	pine_mesh.bottom_radius = 1.6
	pine_mesh.height = 5.0
	pine_mesh.radial_segments = 8

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var placed := 0
	var attempts := 0
	while placed < 70 and attempts < 500:
		attempts += 1
		var pos := Vector3(rng.randf_range(-240, 240), 0, rng.randf_range(-240, 240))
		if _distance_to_track(pos) < TRACK_WIDTH / 2.0 + 6.0:
			continue
		var near_stand := false
		for s in _stand_spots:
			if pos.distance_to(s) < 22.0:
				near_stand = true
				break
		if near_stand:
			continue
		placed += 1
		var scale_factor := rng.randf_range(0.8, 1.6)
		var leaf_mat: StandardMaterial3D = greens[rng.randi() % greens.size()]

		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position = pos + Vector3(0, 1.5 * scale_factor, 0)
		trunk.scale = Vector3.ONE * scale_factor
		add_child(trunk)

		if rng.randf() < 0.3:
			# Pine: a single tall cone.
			var pine := MeshInstance3D.new()
			pine.mesh = pine_mesh
			pine.material_override = leaf_mat
			pine.position = pos + Vector3(0, 4.6 * scale_factor, 0)
			pine.scale = Vector3.ONE * scale_factor
			add_child(pine)
		else:
			# Deciduous: a cluster of 2-3 offset blobs.
			var blobs := 2 + (rng.randi() % 2)
			for b in blobs:
				var blob := MeshInstance3D.new()
				blob.mesh = blob_mesh
				blob.material_override = leaf_mat
				var jitter := Vector3(
					rng.randf_range(-0.7, 0.7), rng.randf_range(-0.3, 0.5),
					rng.randf_range(-0.7, 0.7)) * scale_factor
				blob.position = pos + Vector3(0, 4.0 * scale_factor, 0) + jitter
				blob.scale = Vector3.ONE * scale_factor * rng.randf_range(0.7, 1.0)
				add_child(blob)

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

	# Keep the tiles inside the edge lines so nothing z-fights.
	var line_width := TRACK_WIDTH - 2.6
	var cols := 12
	var tile_size := line_width / cols
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(tile_size, 0.06, tile_size)
	for row in 2:
		for c in cols:
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.material_override = white if (row + c) % 2 == 0 else black
			tile.position = Vector3(
				-line_width / 2.0 + tile_size * (c + 0.5),
				-1.86,
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
