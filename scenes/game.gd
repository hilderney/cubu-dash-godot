extends Node2D

## World scrolls toward the player (Geometry Dash / Robot Unicorn Attack style).
## Player stays fixed on X; only jump and dash are controlled.
## Dash scroll boost follows EventBus.player_dashed / player_dash_ended (Player owns duration).

@export var base_scroll_speed: float = 350.0
@export var dash_scroll_multiplier: float = 2.2
@export var camera_look_ahead: float = 420.0

@onready var player: CharacterBody2D = $Player
@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D

var _scroll_speed: float = 0.0
var _spawn_x: float = 0.0


func _ready() -> void:
	GameManager.start_run()
	_scroll_speed = base_scroll_speed
	_spawn_x = player.global_position.x
	_lock_player_x()
	_update_camera()

	if not EventBus.player_dashed.is_connected(_on_player_dashed):
		EventBus.player_dashed.connect(_on_player_dashed)
	if not EventBus.player_dash_ended.is_connected(_on_player_dash_ended):
		EventBus.player_dash_ended.connect(_on_player_dash_ended)


func _physics_process(delta: float) -> void:
	world.position.x -= _scroll_speed * delta
	_lock_player_x()
	_update_camera()


func _lock_player_x() -> void:
	player.global_position.x = _spawn_x


func _update_camera() -> void:
	camera.global_position = Vector2(
		player.global_position.x + camera_look_ahead,
		camera.global_position.y
	)


func _on_player_dashed() -> void:
	_scroll_speed = base_scroll_speed * dash_scroll_multiplier


func _on_player_dash_ended() -> void:
	_scroll_speed = base_scroll_speed
