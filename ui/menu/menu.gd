extends Control

# Draws the smoothed outline of a track, scaled to fit its box.
class TrackPreview:
	extends Control
	var points: Array = []

	func _init(track_points: Array) -> void:
		points = track_points
		custom_minimum_size = Vector2(150, 120)

	func _draw() -> void:
		var curve := Curve2D.new()
		var n := points.size()
		for i in n + 1:
			var p: Vector2 = points[i % n]
			var prev: Vector2 = points[(i - 1 + n) % n]
			var next: Vector2 = points[(i + 1) % n]
			var tangent := (next - prev) * 0.25
			curve.add_point(p, -tangent, tangent)
		curve.bake_interval = 4.0
		var baked := curve.get_baked_points()

		var bounds := Rect2(baked[0], Vector2.ZERO)
		for p in baked:
			bounds = bounds.expand(p)
		var margin := 10.0
		var scale_factor: float = minf(
			(size.x - margin * 2) / bounds.size.x,
			(size.y - margin * 2) / bounds.size.y)
		var offset := size / 2.0 - bounds.get_center() * scale_factor

		var screen_pts := PackedVector2Array()
		for p in baked:
			screen_pts.append(p * scale_factor + offset)
		screen_pts.append(screen_pts[0])
		draw_polyline(screen_pts, Color(0.9, 0.9, 0.95), 3.0, true)
		# Start/finish marker.
		draw_circle(screen_pts[0], 4.0, Color(0.9, 0.15, 0.15))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "RACE WHEEL"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a track"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(subtitle)

	for i in TrackData.TRACKS.size():
		var track: Dictionary = TrackData.TRACKS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		vbox.add_child(row)

		row.add_child(TrackPreview.new(track.points))

		var button := Button.new()
		var best: float = RaceManager.best_time_for(i)
		var best_text := "--" if best == INF else "%.2f s" % best
		button.text = "%s\nBest: %s" % [track.name, best_text]
		button.add_theme_font_size_override("font_size", 26)
		button.custom_minimum_size = Vector2(340, 100)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_start_track.bind(i))
		row.add_child(button)

	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size", 22)
	quit.custom_minimum_size = Vector2(0, 44)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit)

func _start_track(index: int) -> void:
	RaceManager.select_track(index)
	get_tree().change_scene_to_file("res://race/race.tscn")
