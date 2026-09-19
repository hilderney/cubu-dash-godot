extends Node2D

## World scrolls toward the player (Geometry Dash / Robot Unicorn Attack style).
## Player stays fixed on X; only jump and dash are controlled.
## Dash scroll boost follows EventBus.player_dashed / player_dash_ended (Player owns duration).

const DEV_TUNING_PANEL := preload("res://scenes/hud/DevTuningPanel.tscn")
const Phase00Lab := preload("res://stages/dev/phase_00_lab.gd")

@export var base_scroll_speed: float = 350.0
@export var dash_scroll_multiplier: float = 2.2
@export var camera_look_ahead: float = 420.0

@onready var player: CharacterBody2D = $Player
@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D

var _scroll_speed: float = 0.0
var _spawn_x: float = 0.0
var _player_dead: bool = false


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
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)

	if GameManager.is_dev_lab_run and GameManager.IS_DEV_BUILD:
		_setup_dev_lab()


func _setup_dev_lab() -> void:
	Phase00Lab.build(world)
	var panel := DEV_TUNING_PANEL.instantiate()
	add_child(panel)
	if panel.has_method("setup"):
		panel.setup(self, player)


func _physics_process(delta: float) -> void:
	if _player_dead:
		return
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


func _on_player_died() -> void:
	if _player_dead:
		return
	_player_dead = true
	get_tree().paused = false
	if GameManager.is_dev_lab_run:
		# Keep is_dev_lab_run; reload catalog run.
		get_tree().reload_current_scene()
		return
	GameManager.end_run()
	GameManager.go_main_menu()
