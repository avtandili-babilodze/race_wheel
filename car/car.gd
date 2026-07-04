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

func _build_chassis() -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.8, 4.2)
	collision.shape = box
	collision.position = Vector3(0, 0.5, 0)
	add_child(collision)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.8, 0.08, 0.08)
	paint.metallic = 0.7
	paint.roughness = 0.25

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.14)
	glass.metallic = 0.9
	glass.roughness = 0.1

	var body_mesh := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(1.8, 0.55, 4.0)
	body_mesh.mesh = body_box
	body_mesh.position = Vector3(0, 0.45, 0)
	body_mesh.material_override = paint
	add_child(body_mesh)

	# Sloped-looking nose: a lower, shorter box ahead of the body.
	var nose := MeshInstance3D.new()
	var nose_box := BoxMesh.new()
	nose_box.size = Vector3(1.7, 0.35, 0.8)
	nose.mesh = nose_box
	nose.position = Vector3(0, 0.38, -2.2)
	nose.material_override = paint
	add_child(nose)

	var cabin := MeshInstance3D.new()
	var cabin_box := BoxMesh.new()
	cabin_box.size = Vector3(1.4, 0.45, 1.9)
	cabin.mesh = cabin_box
	cabin.position = Vector3(0, 0.95, 0.1)
	cabin.material_override = glass
	add_child(cabin)

	var spoiler := MeshInstance3D.new()
	var spoiler_box := BoxMesh.new()
	spoiler_box.size = Vector3(1.6, 0.08, 0.5)
	spoiler.mesh = spoiler_box
	spoiler.position = Vector3(0, 1.05, 1.9)
	spoiler.material_override = paint
	add_child(spoiler)

	var headlight := StandardMaterial3D.new()
	headlight.albedo_color = Color(1, 1, 0.85)
	headlight.emission_enabled = true
	headlight.emission = Color(1, 1, 0.8)
	headlight.emission_energy_multiplier = 2.0

	var taillight := StandardMaterial3D.new()
	taillight.albedo_color = Color(1, 0.1, 0.1)
	taillight.emission_enabled = true
	taillight.emission = Color(1, 0.05, 0.05)
	taillight.emission_energy_multiplier = 2.0

	for side in [-1, 1]:
		var head := MeshInstance3D.new()
		var head_box := BoxMesh.new()
		head_box.size = Vector3(0.35, 0.15, 0.05)
		head.mesh = head_box
		head.position = Vector3(side * 0.6, 0.45, -2.61)
		head.material_override = headlight
		add_child(head)

		var tail := MeshInstance3D.new()
		var tail_box := BoxMesh.new()
		tail_box.size = Vector3(0.45, 0.12, 0.05)
		tail.mesh = tail_box
		tail.position = Vector3(side * 0.55, 0.55, 2.01)
		tail.material_override = taillight
		add_child(tail)

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

		var tire := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.35
		cyl.height = 0.3
		tire.mesh = cyl
		tire.rotation_degrees = Vector3(0, 0, 90)
		tire.material_override = rubber
		wheel.add_child(tire)

		var cap := MeshInstance3D.new()
		var cap_cyl := CylinderMesh.new()
		cap_cyl.top_radius = 0.2
		cap_cyl.bottom_radius = 0.2
		cap_cyl.height = 0.31
		cap.mesh = cap_cyl
		cap.rotation_degrees = Vector3(0, 0, 90)
		cap.material_override = hub
		wheel.add_child(cap)

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
