class_name Hud
extends CanvasLayer

var time_label: Label
var lap_label: Label
var best_label: Label
var message_label: Label

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	time_label = _make_label(Vector2(20, 20), 32)
	root.add_child(time_label)

	lap_label = _make_label(Vector2(20, 60), 24)
	root.add_child(lap_label)

	best_label = _make_label(Vector2(20, 92), 24)
	root.add_child(best_label)

	message_label = _make_label(Vector2(-200, -50), 64)
	message_label.custom_minimum_size = Vector2(400, 80)
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.visible = false
	root.add_child(message_label)

	var hint := _make_label(Vector2.ZERO, 18)
	hint.text = "W/A/S/D drive  •  R reset  •  Esc menu"
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	root.add_child(hint)

	RaceManager.lap_completed.connect(_on_lap_completed)

func _make_label(pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label

func _process(_delta: float) -> void:
	time_label.text = "Time: %.2f" % RaceManager.current_lap_time
	lap_label.text = "Lap: %d" % RaceManager.lap_count
	if RaceManager.best_lap_time == INF:
		best_label.text = "Best: --"
	else:
		best_label.text = "Best: %.2f" % RaceManager.best_lap_time

func _on_lap_completed(time: float, is_best: bool) -> void:
	var text := "Lap done: %.2fs" % time
	if is_best:
		text += "  NEW BEST!"
	show_message(text)
	await get_tree().create_timer(2.0).timeout
	hide_message()

func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true

func hide_message() -> void:
	message_label.visible = false
