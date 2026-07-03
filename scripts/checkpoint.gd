extends Area3D

var checkpoint_index: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Car:
		RaceManager.checkpoint_crossed(checkpoint_index)
