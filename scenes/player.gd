extends CharacterBody2D

## Player stays fixed on X; the world/screen scrolls toward them.
## Controls: jump (btn_a) and dash (btn_b).

@export var jump_force: float = -600.0
@export var gravity: float = 1200.0
@export var dash_duration: float = 0.2
@export var max_jumps: int = 2

@onready var visual: ColorRect = $ColorRect

enum State { IDLE, RUNNING, JUMPING, DASHING }
var current_state: State = State.RUNNING
var jump_count: int = 0
var is_dashing: bool = false
var dash_timer: float = 0.0
var was_on_floor: bool = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed(InputActions.BTN_A) and jump_count < max_jumps:
		velocity.y = jump_force
		jump_count += 1
		current_state = State.JUMPING
		animate_jump()

	if Input.is_action_just_pressed(InputActions.BTN_B) and not is_dashing:
		start_dash()

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			current_state = State.RUNNING

	# No horizontal movement — Game.gd scrolls the World
	velocity.x = 0.0
	move_and_slide()

	if is_on_floor():
		jump_count = 0
		if not was_on_floor:
			animate_land()
	was_on_floor = is_on_floor()


func start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	current_state = State.DASHING
	# Speeds up world scroll (forward dash feel)
	EventBus.player_dashed.emit()


func animate_jump() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(visual, "scale", Vector2(1.2, 0.7), 0.08)
	tween.tween_property(visual, "scale", Vector2(0.9, 1.3), 0.12)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)


func animate_land() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual, "scale", Vector2(1.2, 0.8), 0.06)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.06)
