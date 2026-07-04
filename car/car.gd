class_name Car
extends VehicleBody3D

# Godot applies engine_force to every traction wheel, so effective thrust
# is 4x these values.
@export var engine_force_max := 1400.0
@export var brake_force := 60.0
@export var reverse_force := 700.0
@export var top_speed := 38.0
@export var top_speed_reverse := 8.0
@export var steer_max_degrees := 32.0
@export var steer_speed := 4.0

@export var camera_distance := 7.0
@export var camera_height := 3.0
@export var camera_smoothing := 6.0

var _spawn_transform: Transform3D
var _camera: Camera3D
var _camera_initialized := false

func _ready() -> void:
	mass = 800.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.2, 0)
	_spawn_transform = transform
	_build_chassis()
	_build_wheels()
	_build_camera()

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi

func _build_chassis() -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.8, 4.2)
	collision.shape = box
	collision.position = Vector3(0, 0.5, 0)
	add_child(collision)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.72, 0.06, 0.06)
	paint.metallic = 0.75
	paint.roughness = 0.3

	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.07, 0.07, 0.08)
	trim.roughness = 0.6

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.14)
	glass.metallic = 0.9
	glass.roughness = 0.1

	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.94, 0.94, 0.92)
	stripe_mat.metallic = 0.2
	stripe_mat.roughness = 0.5

	# Body, low nose, cabin.
	_box(Vector3(1.8, 0.55, 4.0), Vector3(0, 0.45, 0), paint)
	_box(Vector3(1.7, 0.35, 0.8), Vector3(0, 0.38, -2.2), paint)
	_box(Vector3(1.4, 0.45, 1.9), Vector3(0, 0.95, 0.1), glass)

	# Sloped windshield and rear window (wedges).
	var windshield := MeshInstance3D.new()
	var ws_mesh := PrismMesh.new()
	ws_mesh.size = Vector3(0.9, 0.45, 1.38)
	ws_mesh.left_to_right = 0.0
	windshield.mesh = ws_mesh
	windshield.rotation_degrees = Vector3(0, 90, 0)
	windshield.position = Vector3(0, 0.95, -1.3)
	windshield.material_override = glass
	add_child(windshield)

	var rear_window := MeshInstance3D.new()
	var rw_mesh := PrismMesh.new()
	rw_mesh.size = Vector3(0.6, 0.45, 1.38)
	rw_mesh.left_to_right = 1.0
	rear_window.mesh = rw_mesh
	rear_window.rotation_degrees = Vector3(0, 90, 0)
	rear_window.position = Vector3(0, 0.95, 1.35)
	rear_window.material_override = glass
	add_child(rear_window)

	# Racing stripes: hood, roof, trunk.
	for sx: float in [-0.15, 0.15]:
		_box(Vector3(0.18, 0.03, 1.1), Vector3(sx, 0.741, -1.43), stripe_mat)
		_box(Vector3(0.18, 0.03, 1.86), Vector3(sx, 1.191, 0.1), stripe_mat)
		_box(Vector3(0.18, 0.03, 0.9), Vector3(sx, 0.741, 1.53), stripe_mat)

	# Aero and trim details.
	_box(Vector3(1.9, 0.09, 0.35), Vector3(0, 0.14, -2.45), trim)      # splitter
	_box(Vector3(1.9, 0.09, 0.35), Vector3(0, 0.14, 2.05), trim)       # diffuser
	_box(Vector3(0.9, 0.16, 0.05), Vector3(0, 0.28, -2.62), trim)      # grille
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.1, 2.2), Vector3(side * 0.92, 0.2, -0.1), trim)  # skirt
		_box(Vector3(0.24, 0.09, 0.14), Vector3(side * 0.84, 1.0, -0.52), trim)  # mirror

	# Rear wing on struts.
	var wing := _box(Vector3(1.7, 0.07, 0.5), Vector3(0, 1.12, 1.95), paint)
	wing.rotation_degrees = Vector3(-8, 0, 0)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.32, 0.3), Vector3(side * 0.6, 0.9, 1.95), trim)

	# Exhaust pipes.
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.6, 0.6, 0.62)
	pipe_mat.metallic = 1.0
	pipe_mat.roughness = 0.25
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 0.06
	pipe_mesh.bottom_radius = 0.06
	pipe_mesh.height = 0.3
	for sx: float in [-0.35, 0.35]:
		var pipe := MeshInstance3D.new()
		pipe.mesh = pipe_mesh
		pipe.rotation_degrees = Vector3(90, 0, 0)
		pipe.position = Vector3(sx, 0.24, 2.05)
		pipe.material_override = pipe_mat
		add_child(pipe)

	# Lights.
	var headlight := StandardMaterial3D.new()
	headlight.albedo_color = Color(1, 1, 0.85)
	headlight.emission_enabled = true
	headlight.emission = Color(1, 1, 0.8)
	headlight.emission_energy_multiplier = 2.5

	var taillight := StandardMaterial3D.new()
	taillight.albedo_color = Color(1, 0.1, 0.1)
	taillight.emission_enabled = true
	taillight.emission = Color(1, 0.05, 0.05)
	taillight.emission_energy_multiplier = 2.5

	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.35, 0.15, 0.05), Vector3(side * 0.6, 0.45, -2.61), headlight)
		_box(Vector3(0.45, 0.12, 0.05), Vector3(side * 0.55, 0.55, 2.01), taillight)

	# Door numbers.
	for side: float in [-1.0, 1.0]:
		var number := Label3D.new()
		number.text = "7"
		number.font_size = 160
		number.pixel_size = 0.0035
		number.modulate = Color(0.95, 0.95, 0.92)
		number.outline_size = 32
		number.outline_modulate = Color(0.07, 0.07, 0.08)
		number.position = Vector3(side * 0.905, 0.48, -0.2)
		number.rotation_degrees = Vector3(0, 90.0 * side, 0)
		add_child(number)

func _build_wheels() -> void:
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	rubber.roughness = 0.9

	var hub := StandardMaterial3D.new()
	hub.albedo_color = Color(0.75, 0.75, 0.78)
	hub.metallic = 0.9
	hub.roughness = 0.3

	var positions := {
		"fl": Vector3(-0.85, 0.0, -1.4),
		"fr": Vector3(0.85, 0.0, -1.4),
		"rl": Vector3(-0.85, 0.0, 1.4),
		"rr": Vector3(0.85, 0.0, 1.4),
	}
	for key: String in positions:
		var wheel := VehicleWheel3D.new()
		wheel.position = positions[key]
		wheel.wheel_radius = 0.35
		wheel.wheel_rest_length = 0.2
		wheel.suspension_travel = 0.25
		# Godot multiplies stiffness by chassis mass internally, so this
		# behaves like acceleration per metre of compression (~m/s^2 / m).
		wheel.suspension_stiffness = 55.0
		wheel.suspension_max_force = 15000.0
		wheel.use_as_traction = true
		if key.begins_with("f"):
			wheel.use_as_steering = true
			wheel.wheel_friction_slip = 5.5
		else:
			# Slightly grippier rear keeps the tail planted (mild understeer
			# is more forgiving than snap oversteer).
			wheel.wheel_friction_slip = 6.0
		add_child(wheel)

		# Torus tire reads much rounder than a flat cylinder.
		var tire := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.16
		torus.outer_radius = 0.35
		tire.mesh = torus
		tire.rotation_degrees = Vector3(0, 0, 90)
		tire.material_override = rubber
		wheel.add_child(tire)

		var rim := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = 0.17
		rim_cyl.bottom_radius = 0.17
		rim_cyl.height = 0.22
		rim.mesh = rim_cyl
		rim.rotation_degrees = Vector3(0, 0, 90)
		rim.material_override = hub
		wheel.add_child(rim)

		var hub_dot := MeshInstance3D.new()
		var dot_cyl := CylinderMesh.new()
		dot_cyl.top_radius = 0.055
		dot_cyl.bottom_radius = 0.055
		dot_cyl.height = 0.26
		hub_dot.mesh = dot_cyl
		hub_dot.rotation_degrees = Vector3(0, 0, 90)
		hub_dot.material_override = rubber
		wheel.add_child(hub_dot)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 72
	_camera.current = true
	add_child(_camera)
	# Detach from the car's transform so it can follow smoothly
	# instead of tilting with every bump.
	_camera.top_level = true

func _process(delta: float) -> void:
	var back := global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.001:
		back = Vector3.BACK
	back = back.normalized()
	var target := global_position + back * camera_distance + Vector3.UP * camera_height

	if not _camera_initialized:
		_camera.global_position = target
		_camera_initialized = true
	else:
		var weight := 1.0 - exp(-camera_smoothing * delta)
		_camera.global_position = _camera.global_position.lerp(target, weight)
	_camera.look_at(global_position + Vector3.UP * 1.0)

func _physics_process(delta: float) -> void:
	var steer_dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		steer_dir += 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		steer_dir -= 1.0
	# Tighten the steering range as speed rises: full lock when parked,
	# ~35% of it at highway speed, so the car doesn't spin out.
	var speed := linear_velocity.length()
	var steer_scale: float = clamp(1.0 - speed / 35.0, 0.35, 1.0)
	var target_steer := steer_dir * deg_to_rad(steer_max_degrees) * steer_scale
	steering = move_toward(steering, target_steer, steer_speed * delta)

	var throttle := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		throttle = 1.0
	var braking := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)

	# Positive engine_force pushes toward the body's +Z; the nose faces -Z,
	# so forward needs a negative force.
	var forward_speed := linear_velocity.dot(-global_transform.basis.z)
	if braking and forward_speed > 0.5:
		engine_force = 0.0
		brake = brake_force
	elif braking:
		engine_force = reverse_force if forward_speed > -top_speed_reverse else 0.0
		brake = 0.0
	else:
		var cutoff := 0.0 if forward_speed > top_speed else 1.0
		engine_force = -throttle * engine_force_max * cutoff
		brake = 0.0

	if Input.is_physical_key_pressed(KEY_R):
		_reset()

func _reset() -> void:
	transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
