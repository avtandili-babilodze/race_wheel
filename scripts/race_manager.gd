extends Node

signal race_started
signal lap_completed(time: float, is_best: bool)

const NUM_CHECKPOINTS := 4
const SAVE_PATH := "user://best_lap.save"

var running := false
var current_lap_time := 0.0
var lap_count := 0
var best_lap_time := INF
var next_checkpoint := 1

func _ready() -> void:
	_load_best_time()

func _process(delta: float) -> void:
	if running:
		current_lap_time += delta

func start_race() -> void:
	running = true
	current_lap_time = 0.0
	lap_count = 0
	next_checkpoint = 1
	race_started.emit()

func checkpoint_crossed(index: int) -> void:
	if not running or index != next_checkpoint:
		return
	if index == 0:
		lap_count += 1
		var is_best := current_lap_time < best_lap_time
		if is_best:
			best_lap_time = current_lap_time
			_save_best_time()
		lap_completed.emit(current_lap_time, is_best)
		current_lap_time = 0.0
	next_checkpoint = (index + 1) % NUM_CHECKPOINTS

func _save_best_time() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_float(best_lap_time)

func _load_best_time() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			best_lap_time = f.get_float()
