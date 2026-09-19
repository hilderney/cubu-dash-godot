extends Area2D

## Kill volume — touching the player ends the run (fall / pit).


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	# TODO: AUDIO — player died (kill zone)
	EventBus.player_died.emit()
