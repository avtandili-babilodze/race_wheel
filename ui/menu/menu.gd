extends Control

const ACCENT := Color(0.85, 0.18, 0.14)
const GOLD := Color(0.95, 0.78, 0.3)
const TEXT_DIM := Color(1, 1, 1, 0.55)

class TrackPreview:
	extends Control
	var points: Array = []

	func _init(track_points: Array) -> void:
		points = track_points
		custom_minimum_size = Vector2(160, 115)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var baked := TrackData.build_curve2d(points).get_baked_points()
		var bounds := Rect2(baked[0], Vector2.ZERO)
		for p in baked:
			bounds = bounds.expand(p)
		var margin := 14.0
		var scale_factor: float = minf(
			(size.x - margin * 2) / bounds.size.x,
			(size.y - margin * 2) / bounds.size.y)
		var offset := size / 2.0 - bounds.get_center() * scale_factor

		var screen_pts := PackedVector2Array()
		for p in baked:
			screen_pts.append(p * scale_factor + offset)
		screen_pts.append(screen_pts[0])
		
		draw_polyline(screen_pts, Color(0, 0, 0, 0.4), 7.0, true)
		draw_polyline(screen_pts, Color(0.93, 0.94, 0.97), 3.5, true)
		draw_circle(screen_pts[0], 6.0, Color(0.85, 0.18, 0.14))
		draw_circle(screen_pts[0], 2.6, Color.WHITE)

class CarPreview:
	extends Control
	var spec: Dictionary

	func _init(car_spec: Dictionary) -> void:
		spec = car_spec
		custom_minimum_size = Vector2(150, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		# Fit the side-view profile (metres, +y up) plus wheels into the rect.
		var wheel_z: float = spec.wheel_z
		var wheel_r: float = spec.wheel_radius
		var min_x := minf(-wheel_z - wheel_r, 10.0)
		var max_x := maxf(wheel_z + wheel_r, -10.0)
		var max_y := 0.0
		for p: Vector2 in spec.profile:
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			max_y = maxf(max_y, p.y)
		var margin := 6.0
		var s: float = minf(
			(size.x - margin * 2) / (max_x - min_x),
			(size.y - margin * 2) / max_y)
		var origin := Vector2(
			size.x / 2.0 - (min_x + max_x) / 2.0 * s,
			size.y / 2.0 + max_y / 2.0 * s)

		var poly := PackedVector2Array()
		for p: Vector2 in spec.profile:
			poly.append(origin + Vector2(p.x * s, -p.y * s))
		draw_colored_polygon(poly, spec.paint)
		for z: float in [-wheel_z, wheel_z]:
			var center: Vector2 = origin + Vector2(z * s, -wheel_r * s)
			draw_circle(center, wheel_r * s, Color(0.05, 0.05, 0.05))
			draw_circle(center, wheel_r * s * 0.45, Color(0.7, 0.7, 0.73))

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.11, 0.13, 0.18))
	gradient.set_color(1, Color(0.04, 0.05, 0.08))
	
	var bg_tex := GradientTexture2D.new()
	bg_tex.gradient = gradient
	bg_tex.fill_from = Vector2(0, 0)
	bg_tex.fill_to = Vector2(0, 1)
	
	# --- THE FIX: Detach background layout from the UI tree ---
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1 # Forces it strictly behind all UI
	add_child(bg_layer)
	
	var bg := TextureRect.new()
	bg.texture = bg_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
	bg_layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) 
	# ----------------------------------------------------------

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "RACE WHEEL"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var accent := ColorRect.new()
	accent.color = ACCENT
	accent.custom_minimum_size = Vector2(360, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(accent)

	var subtitle := Label.new()
	subtitle.text = "CHOOSE  YOUR  CAR  &  TRACK"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var car_row := HBoxContainer.new()
	car_row.add_theme_constant_override("separation", 16)
	car_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(car_row)

	var car_group := ButtonGroup.new()
	for i in CarData.CARS.size():
		car_row.add_child(_make_car_card(i, car_group))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards)

	var first_card: Button
	for i in TrackData.TRACKS.size():
		var card := _make_card(i)
		cards.add_child(card)
		if i == 0:
			first_card = card

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer2)

	var quit := Button.new()
	quit.text = "Quit"
	quit.flat = true
	quit.add_theme_font_size_override("font_size", 18)
	quit.add_theme_color_override("font_color", TEXT_DIM)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit)

	first_card.grab_focus()

func _card_style(border: Color, bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	return style

# Inset content column for a card button: the stylebox content margin only
# applies to the button's own text, not to child controls.
func _card_content(card: Button) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_top = 12
	content.offset_right = -14
	content.offset_bottom = -12
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	return content

func _make_car_card(index: int, group: ButtonGroup) -> Button:
	var spec: Dictionary = CarData.CARS[index]

	var card := Button.new()
	card.custom_minimum_size = Vector2(232, 124)
	card.toggle_mode = true
	card.button_group = group
	card.button_pressed = index == RaceManager.selected_car
	card.add_theme_stylebox_override("normal",
		_card_style(Color(0.24, 0.27, 0.33), Color(0.12, 0.14, 0.19)))
	card.add_theme_stylebox_override("hover",
		_card_style(GOLD.darkened(0.25), Color(0.15, 0.17, 0.22)))
	card.add_theme_stylebox_override("pressed",
		_card_style(GOLD, Color(0.15, 0.17, 0.22)))
	card.add_theme_stylebox_override("focus",
		_card_style(GOLD, Color(0.15, 0.17, 0.22)))
	card.pressed.connect(RaceManager.select_car.bind(index))

	var content := _card_content(card)
	content.add_child(CarPreview.new(spec))

	var name_label := Label.new()
	name_label.text = spec.name
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var stats := Label.new()
	stats.text = "%s  ·  %d km/h" % [spec.car_class, roundi(spec.top_speed * 3.6)]
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", TEXT_DIM)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stats)

	return card

func _make_card(index: int) -> Button:
	var track: Dictionary = TrackData.TRACKS[index]

	var card := Button.new()
	card.custom_minimum_size = Vector2(200, 270)
	card.add_theme_stylebox_override("normal",
		_card_style(Color(0.24, 0.27, 0.33), Color(0.12, 0.14, 0.19)))
	card.add_theme_stylebox_override("hover",
		_card_style(ACCENT, Color(0.15, 0.17, 0.22)))
	card.add_theme_stylebox_override("pressed",
		_card_style(ACCENT, Color(0.09, 0.1, 0.14)))
	card.add_theme_stylebox_override("focus",
		_card_style(ACCENT.lightened(0.2), Color(0.15, 0.17, 0.22)))
	card.pressed.connect(_start_track.bind(index))

	var content := _card_content(card)

	content.add_child(TrackPreview.new(track.points))

	var name_label := Label.new()
	name_label.text = track.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var length_m := TrackData.build_curve2d(track.points).get_baked_length()
	var length_label := Label.new()
	length_label.text = "%.2f km lap" % (length_m / 1000.0)
	length_label.add_theme_font_size_override("font_size", 15)
	length_label.add_theme_color_override("font_color", TEXT_DIM)
	length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(length_label)

	var best := RaceManager.best_time_for(index)
	var best_label := Label.new()
	if best == INF:
		best_label.text = "no best time yet"
		best_label.add_theme_color_override("font_color", TEXT_DIM)
	else:
		best_label.text = "best  %.2f s" % best
		best_label.add_theme_color_override("font_color", GOLD)
	best_label.add_theme_font_size_override("font_size", 15)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(best_label)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(filler)

	var cta := Label.new()
	cta.text = "—  ENTER RACE  —"
	cta.add_theme_font_size_override("font_size", 13)
	cta.add_theme_color_override("font_color", TEXT_DIM)
	cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cta)

	return card

func _start_track(index: int) -> void:
	RaceManager.select_track(index)
	get_tree().change_scene_to_file("res://race/race.tscn")
