class_name CarBody

# Procedural 3D bodies for the cars in CarData.CARS — the "body" key picks
# the builder. Only cosmetic geometry lives here; car.gd owns physics
# (collision shape and wheels). All builders share the same primitive
# helpers and material palette so the cars read as one family.

const TRIM := Color(0.07, 0.07, 0.08)
const GLASS := Color(0.08, 0.1, 0.14)
const WHITE := Color(0.94, 0.94, 0.92)

static func build(car: Node3D, spec: Dictionary) -> void:
	match spec.body:
		"muscle": _muscle(car, spec.paint)
		"sports": _sports(car, spec.paint)
		"supercar": _supercar(car, spec.paint)
		"formula": _formula(car, spec.paint)

# --- primitive and material helpers ---

static func _mat(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

static func _glow(color: Color) -> StandardMaterial3D:
	var mat := _mat(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	return mat

static func _box(car: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	car.add_child(mi)
	return mi

# Sloped panel (windshield, rear window, nose wedge). PrismMesh slopes along
# its own x, so it is yawed 90°: `size` is (width, height, depth) in car
# space, and slope_back selects which way the face leans.
static func _wedge(car: Node3D, size: Vector3, pos: Vector3, mat: Material,
		slope_back: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size.z, size.y, size.x)
	mesh.left_to_right = 1.0 if slope_back else 0.0
	mi.mesh = mesh
	mi.rotation_degrees = Vector3(0, 90, 0)
	mi.position = pos
	mi.material_override = mat
	car.add_child(mi)
	return mi

static func _exhaust_pipes(car: Node3D, xs: Array, pos_y: float, pos_z: float) -> void:
	var mat := _mat(Color(0.6, 0.6, 0.62), 1.0, 0.25)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = 0.3
	for x: float in xs:
		var pipe := MeshInstance3D.new()
		pipe.mesh = mesh
		pipe.rotation_degrees = Vector3(90, 0, 0)
		pipe.position = Vector3(x, pos_y, pos_z)
		pipe.material_override = mat
		car.add_child(pipe)

# --- bodies ---

static func _muscle(car: Node3D, paint_color: Color) -> void:
	var paint := _mat(paint_color, 0.75, 0.3)
	var trim := _mat(TRIM, 0.0, 0.6)
	var glass := _mat(GLASS, 0.9, 0.1)
	var stripe := _mat(WHITE, 0.2, 0.5)

	# Body, low nose, cabin.
	_box(car, Vector3(1.8, 0.55, 4.0), Vector3(0, 0.45, 0), paint)
	_box(car, Vector3(1.7, 0.35, 0.8), Vector3(0, 0.38, -2.2), paint)
	_box(car, Vector3(1.4, 0.45, 1.9), Vector3(0, 0.95, 0.1), glass)
	_wedge(car, Vector3(1.38, 0.45, 0.9), Vector3(0, 0.95, -1.3), glass, false)
	_wedge(car, Vector3(1.38, 0.45, 0.6), Vector3(0, 0.95, 1.35), glass, true)

	# Racing stripes: hood, roof, trunk.
	for sx: float in [-0.15, 0.15]:
		_box(car, Vector3(0.18, 0.03, 1.1), Vector3(sx, 0.741, -1.43), stripe)
		_box(car, Vector3(0.18, 0.03, 1.86), Vector3(sx, 1.191, 0.1), stripe)
		_box(car, Vector3(0.18, 0.03, 0.9), Vector3(sx, 0.741, 1.53), stripe)

	# Aero and trim details.
	_box(car, Vector3(1.9, 0.09, 0.35), Vector3(0, 0.14, -2.45), trim)      # splitter
	_box(car, Vector3(1.9, 0.09, 0.35), Vector3(0, 0.14, 2.05), trim)       # diffuser
	_box(car, Vector3(0.9, 0.16, 0.05), Vector3(0, 0.28, -2.62), trim)      # grille
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.06, 0.1, 2.2), Vector3(side * 0.92, 0.2, -0.1), trim)  # skirt
		_box(car, Vector3(0.24, 0.09, 0.14), Vector3(side * 0.84, 1.0, -0.52), trim)  # mirror

	# Rear wing on struts.
	var wing := _box(car, Vector3(1.7, 0.07, 0.5), Vector3(0, 1.12, 1.95), paint)
	wing.rotation_degrees = Vector3(-8, 0, 0)
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.08, 0.32, 0.3), Vector3(side * 0.6, 0.9, 1.95), trim)

	_exhaust_pipes(car, [-0.35, 0.35], 0.24, 2.05)

	var headlight := _glow(Color(1, 1, 0.85))
	var taillight := _glow(Color(1, 0.08, 0.08))
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.35, 0.15, 0.05), Vector3(side * 0.6, 0.45, -2.61), headlight)
		_box(car, Vector3(0.45, 0.12, 0.05), Vector3(side * 0.55, 0.55, 2.01), taillight)

	# Door numbers.
	for side: float in [-1.0, 1.0]:
		var number := Label3D.new()
		number.text = "7"
		number.font_size = 160
		number.pixel_size = 0.0035
		number.modulate = WHITE
		number.outline_size = 32
		number.outline_modulate = TRIM
		number.position = Vector3(side * 0.905, 0.48, -0.2)
		number.rotation_degrees = Vector3(0, 90.0 * side, 0)
		car.add_child(number)

static func _sports(car: Node3D, paint_color: Color) -> void:
	var paint := _mat(paint_color, 0.7, 0.35)
	var trim := _mat(TRIM, 0.0, 0.6)
	var glass := _mat(GLASS, 0.9, 0.1)

	# Long low body with a tapered nose and fastback cabin.
	_box(car, Vector3(1.75, 0.5, 3.9), Vector3(0, 0.4, 0), paint)
	_box(car, Vector3(1.6, 0.32, 0.9), Vector3(0, 0.34, -2.05), paint)
	_box(car, Vector3(1.25, 0.42, 1.5), Vector3(0, 0.84, 0.2), glass)
	_wedge(car, Vector3(1.22, 0.42, 1.1), Vector3(0, 0.84, -1.1), glass, false)
	_wedge(car, Vector3(1.22, 0.42, 1.1), Vector3(0, 0.84, 1.5), glass, true)

	# Ducktail lip instead of a big wing.
	_box(car, Vector3(1.5, 0.07, 0.3), Vector3(0, 0.72, 1.85), trim)

	_box(car, Vector3(1.85, 0.09, 0.3), Vector3(0, 0.13, -2.35), trim)      # splitter
	_box(car, Vector3(1.85, 0.09, 0.3), Vector3(0, 0.13, 1.95), trim)       # diffuser
	_box(car, Vector3(0.8, 0.14, 0.05), Vector3(0, 0.26, -2.52), trim)      # grille
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.06, 0.1, 2.1), Vector3(side * 0.89, 0.18, 0), trim)  # skirt
		_box(car, Vector3(0.22, 0.08, 0.13), Vector3(side * 0.8, 0.9, -0.45), trim)  # mirror
		_box(car, Vector3(0.05, 0.18, 0.5), Vector3(side * 0.88, 0.45, 0.9), trim)  # side vent

	_exhaust_pipes(car, [-0.15, 0.15], 0.22, 1.98)

	var headlight := _glow(Color(1, 1, 0.85))
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.4, 0.1, 0.05), Vector3(side * 0.55, 0.42, -2.51), headlight)
	# Full-width light bar.
	_box(car, Vector3(1.3, 0.09, 0.05), Vector3(0, 0.55, 1.96), _glow(Color(1, 0.08, 0.08)))

static func _supercar(car: Node3D, paint_color: Color) -> void:
	var paint := _mat(paint_color, 0.85, 0.2)
	var trim := _mat(TRIM, 0.0, 0.6)
	var glass := _mat(GLASS, 0.9, 0.1)

	# Very low, wide wedge with a cab-forward canopy and exposed engine deck.
	_box(car, Vector3(1.9, 0.42, 4.0), Vector3(0, 0.36, 0), paint)
	_wedge(car, Vector3(1.7, 0.3, 1.1), Vector3(0, 0.35, -2.0), paint, false)
	_box(car, Vector3(1.3, 0.4, 1.3), Vector3(0, 0.76, -0.35), glass)
	_wedge(car, Vector3(1.28, 0.4, 1.1), Vector3(0, 0.76, -1.55), glass, false)
	_wedge(car, Vector3(1.28, 0.4, 0.7), Vector3(0, 0.76, 0.65), glass, true)
	_box(car, Vector3(1.5, 0.24, 1.2), Vector3(0, 0.66, 1.2), paint)        # engine deck
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.14, 0.22, 0.7), Vector3(side * 0.9, 0.6, 0.4), trim)  # intake
		_box(car, Vector3(0.06, 0.1, 2.2), Vector3(side * 0.94, 0.16, -0.1), trim)  # skirt
		_box(car, Vector3(0.22, 0.08, 0.13), Vector3(side * 0.82, 0.85, -0.85), trim)  # mirror

	# Low wide wing on endplates and a deep diffuser.
	_box(car, Vector3(1.8, 0.06, 0.45), Vector3(0, 0.95, 1.85), paint)
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.06, 0.3, 0.4), Vector3(side * 0.82, 0.78, 1.85), trim)
	_box(car, Vector3(1.9, 0.14, 0.4), Vector3(0, 0.15, 2.0), trim)
	_box(car, Vector3(1.95, 0.08, 0.35), Vector3(0, 0.12, -2.42), trim)     # splitter

	_exhaust_pipes(car, [-0.45, -0.25, 0.25, 0.45], 0.3, 2.0)

	var headlight := _glow(Color(1, 1, 0.85))
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.35, 0.08, 0.05), Vector3(side * 0.6, 0.4, -2.52), headlight)
	_box(car, Vector3(1.4, 0.07, 0.05), Vector3(0, 0.52, 2.01), _glow(Color(1, 0.08, 0.08)))

static func _formula(car: Node3D, paint_color: Color) -> void:
	var paint := _mat(paint_color, 0.6, 0.35)
	var trim := _mat(TRIM, 0.0, 0.6)

	# Narrow tub, nose cone, and front wing.
	_box(car, Vector3(0.85, 0.34, 2.4), Vector3(0, 0.42, 0.2), paint)
	_box(car, Vector3(0.45, 0.22, 1.4), Vector3(0, 0.4, -1.7), paint)
	_box(car, Vector3(1.85, 0.05, 0.5), Vector3(0, 0.22, -2.25), paint)
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.05, 0.14, 0.5), Vector3(side * 0.9, 0.27, -2.25), trim)

	# Cockpit: driver helmet and roll hoop / airbox.
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.16
	helmet_mesh.height = 0.32
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0, 0.66, -0.15)
	helmet.material_override = _mat(WHITE, 0.3, 0.4)
	car.add_child(helmet)
	_box(car, Vector3(0.3, 0.3, 0.5), Vector3(0, 0.72, 0.35), paint)        # airbox

	# Side pods and tapering engine cover.
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.5, 0.28, 1.5), Vector3(side * 0.62, 0.4, 0.45), paint)
	_wedge(car, Vector3(0.4, 0.32, 1.3), Vector3(0, 0.56, 0.95), paint, true)

	# Rear wing on endplates, plus the floor/diffuser.
	_box(car, Vector3(1.5, 0.07, 0.45), Vector3(0, 0.98, 1.85), paint)
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.05, 0.42, 0.45), Vector3(side * 0.72, 0.78, 1.85), trim)
	_box(car, Vector3(0.08, 0.3, 0.08), Vector3(0, 0.78, 1.7), trim)        # strut
	_box(car, Vector3(1.4, 0.06, 0.6), Vector3(0, 0.18, 1.7), trim)

	_box(car, Vector3(0.3, 0.06, 0.05), Vector3(0, 0.5, 2.05), _glow(Color(1, 0.08, 0.08)))
