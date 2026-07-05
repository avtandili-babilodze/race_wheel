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
	env.fog_density = 0.001
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var ground := StaticBody3D.new()
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(1100, 1, 1100)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_col)

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_texture = _noise_tex(
		0.008, Color(0.15, 0.31, 0.12), Color(0.22, 0.4, 0.16))
	grass_mat.uv1_scale = Vector3(110, 110, 1)
	grass_mat.roughness = 1.0
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1100, 1100)
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

	# Mowed apron outside the walls: alternating stripes of groomed turf.
	var mow_light := StandardMaterial3D.new()
	mow_light.albedo_color = Color(0.21, 0.4, 0.16)
	mow_light.roughness = 1.0
	mow_light.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mow_dark := StandardMaterial3D.new()
	mow_dark.albedo_color = Color(0.16, 0.33, 0.12)
	mow_dark.roughness = 1.0
	mow_dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tris_light := PackedVector3Array()
	var tris_dark := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var inner := _rail(xfs, side * (half + 1.8), 0.02)
		var outer := _rail(xfs, side * (half + 7.8), 0.02)
		for i in inner.size() - 1:
			var quad := PackedVector3Array([
				inner[i], outer[i], outer[i + 1],
				inner[i], outer[i + 1], inner[i + 1]])
			if (i / 6) % 2 == 0:
				tris_light.append_array(quad)
			else:
				tris_dark.append_array(quad)
	_add_ribbon(tris_light, mow_light)
	_add_ribbon(tris_dark, mow_dark)

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
	noise.frequency = 0.1
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
	_build_bushes()

# Flat-shaded, noise-jittered sphere (subdivided octahedron) — the building
# block for foliage and bushes. Unit radius; scale per instance.
func _octa_tris(levels: int) -> Array:
	var verts := [
		Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
		Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var faces := [
		[2, 4, 0], [2, 0, 5], [2, 5, 1], [2, 1, 4],
		[3, 0, 4], [3, 5, 0], [3, 1, 5], [3, 4, 1]]
	var tris := []
	for f in faces:
		tris.append([verts[f[0]], verts[f[1]], verts[f[2]]])
	for l in levels:
		var out := []
		for t in tris:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var c: Vector3 = t[2]
			var ab := ((a + b) / 2.0).normalized()
			var bc := ((b + c) / 2.0).normalized()
			var ca := ((c + a) / 2.0).normalized()
			out.append([a, ab, ca])
			out.append([ab, b, bc])
			out.append([ca, bc, c])
			out.append([ab, bc, ca])
		tris = out
	return tris

func _blob_mesh(seed_val: int, jitter: float) -> ArrayMesh:
	# Jitter comes from world-position noise, so shared edge vertices
	# displace identically and the surface stays crack-free.
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for t in _octa_tris(2):
		for v: Vector3 in t:
			var r := 1.0 + noise.get_noise_3d(v.x * 40.0, v.y * 40.0, v.z * 40.0) * jitter
			st.add_vertex(v * r)
	st.generate_normals()
	return st.commit()

# Craggy flat-shaded peak with height-based vertex colours: grassy foot,
# rocky slopes, noisy snow line. Unit height/radius; scaled per instance.
func _mountain_mesh(seed_val: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	var rings := 7
	var sectors := 16
	var grid: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for r in rings + 1:
		var t := float(r) / rings
		var ring_pts := PackedVector3Array()
		var ring_cols := PackedColorArray()
		for s in sectors + 1:
			var ang := TAU * (s % sectors) / sectors
			var n := noise.get_noise_3d(cos(ang) * 40.0, t * 55.0, sin(ang) * 40.0)
			var radius := maxf(pow(1.0 - t, 1.15), 0.02) \
				* (1.0 + n * 0.5 * (1.0 - t * 0.5))
			var h := t + n * 0.1 * (1.0 - t)
			ring_pts.append(Vector3(cos(ang) * radius, h, sin(ang) * radius))
			var c: Color
			if t < 0.1:
				c = Color(0.16, 0.24, 0.15)
			elif h > 0.74 + n * 0.14:
				c = Color(0.88, 0.9, 0.94)
			else:
				c = Color(0.19, 0.21, 0.25).lerp(
					Color(0.11, 0.13, 0.17), n * 0.5 + 0.5)
			ring_cols.append(c)
		grid.append(ring_pts)
		cols.append(ring_cols)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for r in rings:
		for s in sectors:
			var idx := [[r, s], [r, s + 1], [r + 1, s + 1], [r + 1, s]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k: int in tri:
					var rr: int = idx[k][0]
					var ss: int = idx[k][1]
					st.set_color(cols[rr][ss])
					st.add_vertex(grid[rr][ss])
	st.generate_normals()
	return st.commit()

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
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var variants: Array[ArrayMesh] = []
	for v in 4:
		variants.append(_mountain_mesh(rng.randi()))
	# Nine sites around the horizon, each a small range of 1-3 peaks.
	for i in 9:
		var angle := TAU * i / 9 + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(300.0, 345.0)
		var base := Vector3(cos(angle) * r, 0, sin(angle) * r)
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		var peaks := 1 + rng.randi() % 3
		for p in peaks:
			var variant: ArrayMesh = variants[rng.randi() % variants.size()]
			var height := rng.randf_range(45.0, 80.0)
			if p > 0:
				height *= rng.randf_range(0.5, 0.75)
			var spread := rng.randf_range(1.3, 1.9)
			var slide := 0.0
			if p > 0:
				slide = rng.randf_range(-1.6, 1.6) * height
			var pos := base + tangent * slide + Vector3(0, -1.5, 0)
			# Big circuits reach the horizon ring: slide a peak outward until
			# its footprint (noise widens the base up to ~40%) clears the
			# road, and drop it if there is no room left on the ground plane.
			var clearance := height * spread * 1.4 + 12.0
			while _distance_to_track(pos) < clearance and pos.length() < 520.0:
				pos += pos.normalized() * 15.0
			if _distance_to_track(pos) < clearance:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = variant
			mi.material_override = mat
			mi.scale = Vector3(height * spread, height, height * spread)
			mi.position = pos
			mi.rotation.y = rng.randf() * TAU
			add_child(mi)

func _build_trees() -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.16)
	trunk_mat.roughness = 1.0

	var greens: Array[StandardMaterial3D] = []
	for c in [Color(0.13, 0.30, 0.10), Color(0.18, 0.36, 0.12),
			Color(0.24, 0.42, 0.14), Color(0.10, 0.26, 0.11)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		greens.append(m)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var blob_variants: Array[ArrayMesh] = []
	for v in 4:
		blob_variants.append(_blob_mesh(rng.randi(), 0.22))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 3.4
	trunk_mesh.radial_segments = 7

	var pine_meshes: Array[CylinderMesh] = []
	for pr in [[1.7, 2.2], [1.3, 1.8], [0.9, 1.5]]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = pr[0]
		cone.height = pr[1]
		cone.radial_segments = 7
		pine_meshes.append(cone)
	var pine_lift := [0.0, 1.3, 2.5]

	var placed := 0
	var attempts := 0
	while placed < 100 and attempts < 800:
		attempts += 1
		var pos := Vector3(rng.randf_range(-340, 340), 0, rng.randf_range(-340, 340))
		if _distance_to_track(pos) < TRACK_WIDTH / 2.0 + 10.0:
			continue
		var near_stand := false
		for s in _stand_spots:
			if pos.distance_to(s) < 22.0:
				near_stand = true
				break
		if near_stand:
			continue
		placed += 1
		var sf := rng.randf_range(0.8, 1.5)
		var leaf: StandardMaterial3D = greens[rng.randi() % greens.size()]

		# Slight lean and non-uniform scale so no two trees match.
		var tree := Node3D.new()
		tree.position = pos
		tree.rotation_degrees = Vector3(
			rng.randf_range(-3, 3), rng.randf() * 360.0, rng.randf_range(-3, 3))
		tree.scale = Vector3(
			sf * rng.randf_range(0.9, 1.1), sf, sf * rng.randf_range(0.9, 1.1))
		add_child(tree)

		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position = Vector3(0, 1.7, 0)
		tree.add_child(trunk)

		if rng.randf() < 0.35:
			# Pine: three stacked cones.
			for c in 3:
				var cone := MeshInstance3D.new()
				cone.mesh = pine_meshes[c]
				cone.material_override = leaf
				cone.position = Vector3(0, 2.6 + pine_lift[c], 0)
				tree.add_child(cone)
		else:
			# Deciduous: a crown of jittered low-poly blobs.
			var blobs := 3 + (rng.randi() % 2)
			for b in blobs:
				var blob := MeshInstance3D.new()
				blob.mesh = blob_variants[rng.randi() % blob_variants.size()]
				blob.material_override = leaf
				var br := rng.randf_range(1.5, 2.0) if b == 0 \
					else rng.randf_range(1.0, 1.5)
				var off := Vector3.ZERO
				if b > 0:
					off = Vector3(rng.randf_range(-1.1, 1.1),
						rng.randf_range(-0.5, 0.6), rng.randf_range(-1.1, 1.1))
				blob.position = Vector3(0, 4.1, 0) + off
				blob.scale = Vector3(br, br * 0.82, br)
				blob.rotation.y = rng.randf() * TAU
				tree.add_child(blob)

func _build_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mats: Array[StandardMaterial3D] = []
	for c in [Color(0.12, 0.28, 0.10), Color(0.17, 0.33, 0.12)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		mats.append(m)
	var variants: Array[ArrayMesh] = []
	for v in 3:
		variants.append(_blob_mesh(rng.randi(), 0.3))
	var placed := 0
	var attempts := 0
	while placed < 120 and attempts < 900:
		attempts += 1
		var pos := Vector3(rng.randf_range(-340, 340), 0, rng.randf_range(-340, 340))
		if _distance_to_track(pos) < TRACK_WIDTH / 2.0 + 8.5:
			continue
		var near_stand := false
		for s in _stand_spots:
			if pos.distance_to(s) < 16.0:
				near_stand = true
				break
		if near_stand:
			continue
		placed += 1
		var bush := MeshInstance3D.new()
		bush.mesh = variants[rng.randi() % variants.size()]
		bush.material_override = mats[rng.randi() % mats.size()]
		var s := rng.randf_range(0.5, 1.3)
		bush.scale = Vector3(s, s * 0.55, s)
		bush.position = pos + Vector3(0, s * 0.3, 0)
		bush.rotation.y = rng.randf() * TAU
		add_child(bush)

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
	car.spec = CarData.CARS[RaceManager.selected_car]
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
