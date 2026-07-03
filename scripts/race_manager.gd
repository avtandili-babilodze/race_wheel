extends Node

signal race_started
signal lap_completed(time: float, is_best: bool)

const NUM_CHECKPOINTS := 6

var selected_track := 0
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

func select_track(index: int) -> void:
	selected_track = index
	_load_best_time()

func start_race() -> void:
	running = true
	current_lap_time = 0.0
	lap_count = 0
	next_checkpoint = 1
	race_started.emit()

func stop_race() -> void:
	running = false

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

static func best_time_for(track: int) -> float:
	var path := "user://best_lap_%d.save" % track
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_float()
	return INF

func _save_best_time() -> void:
	var f := FileAccess.open("user://best_lap_%d.save" % selected_track, FileAccess.WRITE)
	if f:
		f.store_float(best_lap_time)

func _load_best_time() -> void:
	best_lap_time = best_time_for(selected_track)
