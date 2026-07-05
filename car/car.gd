class_name Car
extends VehicleBody3D

# Driving physics, input, and chase camera. All per-model tuning (forces,
# grip, wheel layout, looks) comes from a CarData.CARS entry: race.gd sets
# `spec` before adding the car to the tree, and CarBody builds the visuals.
var spec: Dictionary = CarData.CARS[0]

@export var camera_distance := 7.0
@export var camera_height := 3.0
@export var camera_smoothing := 6.0

const TOP_SPEED_REVERSE := 8.0

# Godot applies engine_force to every traction wheel, so effective thrust
# is 4x these values.
var engine_force_max: float
var brake_force: float
var reverse_force: float
var top_speed: float
var steer_max: float
var steer_speed: float

var _spawn_transform: Transform3D
var _camera: Camera3D
var _camera_initialized := false

func _ready() -> void:
	engine_force_max = spec.engine_force
	brake_force = spec.brake_force
	reverse_force = spec.reverse_force
	top_speed = spec.top_speed
	steer_max = deg_to_rad(spec.steer_max_degrees)
	steer_speed = spec.steer_speed

	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.2, 0)
	_spawn_transform = transform

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = spec.collision_size
	collision.shape = box
	collision.position = Vector3(0, 0.5, 0)
	add_child(collision)

	CarBody.build(self, spec)
	_build_wheels()
	_build_camera()

func _build_wheels() -> void:
	var radius: float = spec.wheel_radius

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	rubber.roughness = 0.9

	var hub := StandardMaterial3D.new()
	hub.albedo_color = Color(0.75, 0.75, 0.78)
	hub.metallic = 0.9
	hub.roughness = 0.3

	for x_side: float in [-1.0, 1.0]:
		for z_side: float in [-1.0, 1.0]:
			var front := z_side < 0.0
			var wheel := VehicleWheel3D.new()
			wheel.position = Vector3(spec.wheel_x * x_side, 0, spec.wheel_z * z_side)
			wheel.wheel_radius = radius
			wheel.wheel_rest_length = 0.2
			wheel.suspension_travel = 0.25
			# Godot multiplies stiffness by chassis mass internally, so this
			# behaves like acceleration per metre of compression (~m/s^2 / m).
			wheel.suspension_stiffness = 55.0
			wheel.suspension_max_force = 15000.0
			wheel.use_as_traction = true
			wheel.use_as_steering = front
			wheel.wheel_friction_slip = spec.grip_front if front else spec.grip_rear
			add_child(wheel)

			# Torus tire reads much rounder than a flat cylinder.
			var tire := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = radius * 0.46
			torus.outer_radius = radius
			tire.mesh = torus
			tire.rotation_degrees = Vector3(0, 0, 90)
			tire.material_override = rubber
			wheel.add_child(tire)

			var rim := MeshInstance3D.new()
			var rim_cyl := CylinderMesh.new()
			rim_cyl.top_radius = radius * 0.49
			rim_cyl.bottom_radius = radius * 0.49
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
	# ~35% of it near top speed, so the car doesn't spin out.
	var speed := linear_velocity.length()
	var steer_scale: float = clamp(1.0 - speed / (top_speed * 0.92), 0.35, 1.0)
	var target_steer := steer_dir * steer_max * steer_scale
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
		engine_force = reverse_force if forward_speed > -TOP_SPEED_REVERSE else 0.0
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
