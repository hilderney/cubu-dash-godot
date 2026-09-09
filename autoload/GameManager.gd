extends Node

## Estado global da run (fase, moedas, records).

var current_world: int = 0
var coins: int = 0
var records: Dictionary = {}
var is_running: bool = false


func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func start_run() -> void:
	is_running = true


func end_run() -> void:
	is_running = false


func add_coins(amount: int) -> void:
	coins += amount
	EventBus.coin_collected.emit(amount)
