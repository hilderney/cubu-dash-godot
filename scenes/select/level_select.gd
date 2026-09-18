extends Node2D

## Clock-style circular select: World -> Phase.
##
## Short tap: move exactly N slots (1/2/3 taps) with acceleration.
## Hold: continuous chase (selected + look_ahead).
##   look_ahead ramps 1 -> 2 -> 3 over time (0 / 0.8s / 1.8s).
##   Whatever crosses north becomes selected; the target advances with it.
##   At max look-ahead, speed stays constant.
## Reverse: ease-in the other way.
## Confirm/Back/Direction while spinning: queued until park (PendingAction). Latest pending wins.


enum Stage { WORLD, PHASE }
enum SpinMode { IDLE, TAP, HOLD, REVERSE_BOUNCE, SETTLE, TRANSITION }
## Queued after spin finishes. Latest pending wins.
enum PendingAction { NONE, CONFIRM, BACK, SPIN }
## How a select circle enters after a transition.
enum EnterAnim { NONE, ZOOM_IN, DIVE_OUT }

const ITEM_SCENE := preload("res://scenes/select/CarouselItem.tscn")
const MAX_LOOK: int = 3
const HOLD_LOOK_2: float = 0.80
const HOLD_LOOK_3: float = 1.80
const HOLD_MODE_AFTER: float = 0.22 ## held down this long, tap upgrades to continuous hold
const TRANSITION_MS: float = 0.35

const WORLD_COLORS: Array[Color] = [
	Color("FF6B35"), Color("FFE66D"), Color("4ECDC4"), Color("FF8C42"),
	Color("2EC4B6"), Color("E71D36"), Color("FF9F1C"), Color("7BDFF2"),
	Color("F15BB5"), Color("00F5D4"), Color("FEE440"), Color("9B5DE5"),
]

@export var ring_radius: float = 420.0
@export var camera_zoom: Vector2 = Vector2(1.15, 1.15)
@export var speed_look_1: float = 2.8
@export var speed_look_2: float = 4.4
@export var speed_look_3: float = 5.8
@export var angular_accel: float = 22.0
@export var settle_bounce: float = 0.11
@export var settle_duration: float = 0.07
@export var reverse_bounce: float = 0.05
@export var reverse_duration: float = 0.04
@export var tap_window: float = 0.015
@export var transition_duration: float = TRANSITION_MS
## Dive into the north item.
@export var dive_zoom: float = 9.0
## Far / leave framing for ZOOM OUT and ZOOM IN start.
@export var zoom_out_scale: float = 0.18
## How far the camera pulls back when leaving a circle.
@export var zoom_out_pull: float = 0.65
## Ring scale when starting ZOOM IN from far away.
@export var zoom_in_start_scale: float = 0.35
## Extra zoom factor at dock bounce (encaixe).
@export var transition_bounce_zoom: float = 0.07
## Pixel nudge toward the dock target during bounce.
@export var transition_bounce_pixels: float = 22.0
## Duration of the dock bounce only.
@export var transition_bounce_duration: float = 0.03

@onready var camera: Camera2D = %Camera2D
@onready var pivot: Node2D = %Pivot
@onready var carousel: Node2D = %Carousel
@onready var ring_guide: Node2D = %RingGuide
@onready var stage_label: Label = %StageLabel
@onready var selection_label: Label = %SelectionLabel
@onready var hint_label: Label = %HintLabel
@onready var hub: Node2D = %Hub
@onready var hud: CanvasLayer = $HUD

var worlds: Array[Dictionary] = []
var stage: Stage = Stage.WORLD
var selected_world: int = 0
var selected_phase: int = 0
var selected_index: int = 0

var _items: Array[Node2D] = []
var _item_count: int = 0
var _angle_step: float = 0.0

var _mode: SpinMode = SpinMode.IDLE
var _dir: int = 0
var _look_ahead: int = 1
var _tap_count: int = 0
var _angular_vel: float = 0.0

## TAP: fixed destination from gesture origin
var _tap_origin_index: int = 0
var _tap_origin_rotation: float = 0.0
var _tap_target_rotation: float = 0.0

var _holding: bool = false
var _hold_dir: int = 0
var _hold_time: float = 0.0
var _tap_window_left: float = 0.0
var _pending_action: PendingAction = PendingAction.NONE
var _pending_dir: int = 0

var _tween: Tween
var _transition_tween: Tween
var _hud_labels: Array[CanvasItem] = []


func _ready() -> void:
	_hud_labels = [stage_label, selection_label, hint_label]
	_build_world_data()
	camera.zoom = camera_zoom
	# Start Game -> Select World: ZOOM IN
	_enter_world_stage(EnterAnim.ZOOM_IN)
	_draw_ring_guide()


func _input(event: InputEvent) -> void:
	if _mode == SpinMode.TRANSITION:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(InputActions.BTN_B) or event.is_action_pressed(InputActions.BTN_START):
		_request_back()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(InputActions.BTN_A) and not event.is_echo():
		_request_confirm()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(InputActions.RIGHT) and not event.is_echo():
		_request_dir(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.LEFT) and not event.is_echo():
		_request_dir(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(InputActions.RIGHT):
		if _hold_dir == 1:
			_release_dir()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(InputActions.LEFT):
		if _hold_dir == -1:
			_release_dir()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _mode == SpinMode.TRANSITION:
		_update_item_billboards()
		hub.rotation += delta * 0.35
		return

	if _tap_window_left > 0.0:
		_tap_window_left = maxf(0.0, _tap_window_left - delta)

	if _holding and _mode in [SpinMode.TAP, SpinMode.HOLD]:
		_hold_time += delta
		if _mode == SpinMode.TAP and _hold_time >= HOLD_MODE_AFTER:
			_enter_hold_chase(_dir)
		if _mode == SpinMode.HOLD:
			_update_look_ahead_from_hold()

	match _mode:
		SpinMode.TAP:
			_integrate_tap(delta)
		SpinMode.HOLD:
			_integrate_hold(delta)

	_update_item_billboards()
	_update_camera()
	hub.rotation += delta * 0.35


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _request_dir(dir: int) -> void:
	if _mode == SpinMode.TRANSITION:
		return
	# Already chasing this way — keep the hold ramp.
	if _mode == SpinMode.HOLD and dir == _dir:
		_holding = true
		_hold_dir = dir
		return
	if _is_spin_busy():
		_pending_action = PendingAction.SPIN
		_pending_dir = dir
		if _mode == SpinMode.HOLD:
			_begin_settle_for_pending()
		return
	_execute_dir(dir)


func _execute_dir(dir: int) -> void:
	if _mode != SpinMode.IDLE:
		return

	var still_held := (
		(dir > 0 and Input.is_action_pressed(InputActions.RIGHT))
		or (dir < 0 and Input.is_action_pressed(InputActions.LEFT))
	)
	_holding = still_held
	_hold_dir = dir if still_held else 0

	# Same-side taps stay TAP (1 / 2 / 3 slots). Hold only comes from keeping the key down.
	var window_open := _tap_window_left > 0.0
	var continue_same := (
		window_open and dir == _dir and _tap_count > 0
	)
	_tap_window_left = tap_window

	if continue_same:
		_boost_look_ahead_from_tap()
		_tap_origin_index = selected_index
		_tap_origin_rotation = carousel.rotation + _angled(
			carousel.rotation, _slot_rotation(_tap_origin_index)
		)
		_dir = dir
		_retarget_tap()
		_set_selected(posmod(_tap_origin_index + _dir * _look_ahead, _item_count))
		_play_tap_spin()
		return

	# Fresh single tap: one committed step (hold upgrades to continuous chase)
	_dir = dir
	_tap_count = 1
	_look_ahead = 1
	_hold_time = 0.0
	_tap_origin_index = selected_index
	_tap_origin_rotation = carousel.rotation + _angled(carousel.rotation, _slot_rotation(_tap_origin_index))
	_retarget_tap()
	_set_selected(posmod(_tap_origin_index + _dir, _item_count))
	_play_tap_spin()


func _release_dir() -> void:
	_holding = false
	_hold_dir = 0
	if _mode == SpinMode.HOLD:
		_settle_to_nearest()
		return
	# TAP: keep going to the committed destination


func _boost_look_ahead_from_tap() -> void:
	_tap_count = mini(_tap_count + 1, MAX_LOOK)
	_look_ahead = clampi(maxi(_look_ahead, _tap_count), 1, MAX_LOOK)


func _enter_hold_chase(dir: int) -> void:
	_kill_tween()
	_dir = dir
	_mode = SpinMode.HOLD
	if is_zero_approx(_angular_vel):
		_angular_vel = -float(dir) * _speed_for_look(_look_ahead)
	_update_look_ahead_from_hold()


func _update_look_ahead_from_hold() -> void:
	var from_time := 1
	if _hold_time >= HOLD_LOOK_3:
		from_time = 3
	elif _hold_time >= HOLD_LOOK_2:
		from_time = 2
	_look_ahead = clampi(maxi(_look_ahead, maxi(_tap_count, from_time)), 1, MAX_LOOK)


func _retarget_tap() -> void:
	_tap_target_rotation = _tap_origin_rotation - float(_dir * _look_ahead) * _angle_step


func _speed_for_look(look: int) -> float:
	match clampi(look, 1, 3):
		1:
			return speed_look_1
		2:
			return speed_look_2
		_:
			return speed_look_3


# ---------------------------------------------------------------------------
# TAP movement (fixed destination)
# ---------------------------------------------------------------------------

func _integrate_tap(_delta: float) -> void:
	if _mode != SpinMode.TAP:
		return
	_preview_selection_along_path()


func _play_tap_spin() -> void:
	_kill_tween()
	_mode = SpinMode.TAP
	var remaining := absf(_tap_target_rotation - carousel.rotation)
	var duration := remaining / maxf(_speed_for_look(_look_ahead), 0.01)
	duration = maxf(duration, 0.03)
	_angular_vel = -float(_dir) * _speed_for_look(_look_ahead)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(carousel, "rotation", _tap_target_rotation, duration)
	_tween.tween_callback(_on_tap_arrived)


func _on_tap_arrived() -> void:
	if _mode != SpinMode.TAP:
		return
	carousel.rotation = _tap_target_rotation
	if _holding:
		_enter_hold_chase(_dir)
		return
	_park_on_slot(posmod(_tap_origin_index + _dir * _look_ahead, _item_count))


# ---------------------------------------------------------------------------
# HOLD movement (chase selected + look_ahead)
# ---------------------------------------------------------------------------

func _integrate_hold(delta: float) -> void:
	# Whoever is at north is the selection
	var nearest := _index_from_angle(carousel.rotation)
	if nearest != selected_index:
		_set_selected(nearest)

	# Target = N + look_ahead (always ahead of current)
	var base := carousel.rotation + _angled(carousel.rotation, _slot_rotation(selected_index))
	var target := base - float(_dir * _look_ahead) * _angle_step

	# At look 3, speed stays capped at max
	var desired_speed := _speed_for_look(_look_ahead)
	_move_toward_angle(target, desired_speed, delta)

	# Update selection as items pass north
	_preview_selection_along_path()


func _move_toward_angle(target: float, desired_speed: float, delta: float) -> void:
	var remaining := target - carousel.rotation
	if absf(remaining) <= 0.0001:
		_angular_vel = move_toward(_angular_vel, signf(_angular_vel) * desired_speed if not is_zero_approx(_angular_vel) else -float(_dir) * desired_speed, angular_accel * delta)
		# Keep hold speed even when glued to relative target (target moves)
		if _mode == SpinMode.HOLD:
			_angular_vel = -float(_dir) * desired_speed
			carousel.rotation += _angular_vel * delta
		return

	var desired_vel := signf(remaining) * desired_speed
	_angular_vel = move_toward(_angular_vel, desired_vel, angular_accel * delta)
	var step := _angular_vel * delta
	if _mode == SpinMode.TAP and absf(step) >= absf(remaining):
		carousel.rotation = target
		_angular_vel = 0.0
		return
	carousel.rotation += step


func _preview_selection_along_path() -> void:
	var nearest := _index_from_angle(carousel.rotation)
	if nearest != selected_index:
		_set_selected(nearest)


func _settle_to_nearest() -> void:
	_settle_to_index(_index_from_angle(carousel.rotation))


func _settle_to_index(final_index: int) -> void:
	_park_on_slot(final_index)


func _park_on_slot(final_index: int) -> void:
	_kill_tween()
	_set_selected(final_index)
	var final_angle := carousel.rotation + _angled(carousel.rotation, _slot_rotation(final_index))
	carousel.rotation = final_angle
	_angular_vel = 0.0
	_holding = false
	_hold_dir = 0
	_mode = SpinMode.IDLE
	_look_ahead = 1
	if _tap_window_left <= 0.0:
		_dir = 0
		_tap_count = 0
	_apply_selection_visuals()
	_refresh_selection_label()
	_flush_pending_action()


func _set_selected(index: int) -> void:
	selected_index = posmod(index, maxi(_item_count, 1))
	_commit_selection()
	_apply_selection_visuals()
	_refresh_selection_label()


# ---------------------------------------------------------------------------
# Stages / data
# ---------------------------------------------------------------------------

func _build_world_data() -> void:
	worlds.clear()
	var world_names := [
		"NEON CUBES", "PIXEL PEAKS", "VOLT VALLEY", "CANDY CORE",
	]
	for i in world_names.size():
		var phases: Array[Dictionary] = []
		for p in 4:
			phases.append({
				"name": "PHASE %d-%d" % [i + 1, p + 1],
				"id": p,
				"locked": p > 0,
			})
		worlds.append({
			"name": world_names[i],
			"id": i,
			"color": WORLD_COLORS[i % WORLD_COLORS.size()],
			"locked": i > 0,
			"phases": phases,
		})


func _enter_world_stage(enter_anim: EnterAnim = EnterAnim.NONE) -> void:
	_kill_tween()
	_kill_transition()
	_reset_spin()
	stage = Stage.WORLD
	selected_index = selected_world
	stage_label.text = "SELECT WORLD"
	hint_label.text = "LEFT RIGHT SPIN   A CONFIRM   B BACK"
	_rebuild_carousel(_world_entries())
	_snap_visual_to_selected()
	_refresh_selection_label()
	_play_enter_anim(enter_anim)


func _enter_phase_stage(enter_anim: EnterAnim = EnterAnim.NONE) -> void:
	_kill_tween()
	_kill_transition()
	_reset_spin()
	stage = Stage.PHASE
	selected_phase = 0
	selected_index = 0
	stage_label.text = "SELECT PHASE"
	hint_label.text = "LEFT RIGHT SPIN   A PLAY   B WORLDS"
	_rebuild_carousel(_phase_entries(worlds[selected_world]))
	_snap_visual_to_selected()
	_refresh_selection_label()
	_play_enter_anim(enter_anim)


func _play_enter_anim(enter_anim: EnterAnim) -> void:
	match enter_anim:
		EnterAnim.ZOOM_IN:
			_play_zoom_in()
		EnterAnim.DIVE_OUT:
			_play_dive_out()
		_:
			_end_transition_visual_reset()
			_update_camera()
			_set_hud_alpha(1.0)
			_mode = SpinMode.IDLE


func _world_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in worlds:
		out.append({
			"id": w.id,
			"name": w.name,
			"color": w.color,
			"locked": bool(w.get("locked", false)),
		})
	return out


func _phase_entries(world: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in world.phases:
		out.append({
			"id": p.id,
			"name": p.name,
			"color": world.color,
			"locked": bool(p.get("locked", false)),
		})
	return out


func _rebuild_carousel(entries: Array[Dictionary]) -> void:
	for child in carousel.get_children():
		child.queue_free()
	_items.clear()
	_item_count = entries.size()
	_angle_step = TAU / float(_item_count)
	for i in _item_count:
		var entry: Dictionary = entries[i]
		var item: Node2D = ITEM_SCENE.instantiate()
		carousel.add_child(item)
		item.setup(entry.id, entry.name, entry.color, bool(entry.get("locked", false)))
		var angle := -PI / 2.0 + float(i) * _angle_step
		item.position = Vector2(cos(angle), sin(angle)) * ring_radius
		_items.append(item)
	_apply_selection_visuals()


func _reset_spin() -> void:
	_mode = SpinMode.IDLE
	_dir = 0
	_look_ahead = 1
	_tap_count = 0
	_angular_vel = 0.0
	_holding = false
	_hold_dir = 0
	_hold_time = 0.0
	_tap_window_left = 0.0
	_pending_action = PendingAction.NONE
	_pending_dir = 0


func _is_spin_busy() -> bool:
	return _mode in [
		SpinMode.TAP,
		SpinMode.HOLD,
		SpinMode.SETTLE,
		SpinMode.REVERSE_BOUNCE,
	]


## Stop hold so TAP can park; if already HOLD, settle to north now.
func _begin_settle_for_pending() -> void:
	_holding = false
	_hold_dir = 0
	if _mode == SpinMode.HOLD:
		_settle_to_nearest()


func _flush_pending_action() -> void:
	if _pending_action == PendingAction.NONE:
		return
	if _mode != SpinMode.IDLE:
		return
	var action := _pending_action
	var pending_dir := _pending_dir
	_pending_action = PendingAction.NONE
	_pending_dir = 0
	match action:
		PendingAction.CONFIRM:
			_execute_confirm()
		PendingAction.BACK:
			_execute_back()
		PendingAction.SPIN:
			_execute_dir(pending_dir)
		_:
			pass


func _request_confirm() -> void:
	if _mode == SpinMode.TRANSITION:
		return
	if _is_spin_busy():
		_pending_action = PendingAction.CONFIRM
		_begin_settle_for_pending()
		return
	_execute_confirm()


func _request_back() -> void:
	if _mode == SpinMode.TRANSITION:
		return
	if _is_spin_busy():
		_pending_action = PendingAction.BACK
		_begin_settle_for_pending()
		return
	_execute_back()


func _execute_confirm() -> void:
	if _mode != SpinMode.IDLE:
		return

	# IDLE: confirm north item (locked → denied anim, no enter)
	if _is_selected_locked():
		_play_denied_on_selected()
		return

	if stage == Stage.WORLD:
		selected_world = selected_index
		# TODO: AUDIO — confirmed world selection
		# Dive into world, then Select Phase with ZOOM IN
		_play_dive_in(func() -> void:
			_enter_phase_stage(EnterAnim.ZOOM_IN)
		)
	else:
		selected_phase = selected_index
		# TODO: AUDIO — confirmed phase, start run
		# Dive into phase, then start the run
		_play_dive_in(func() -> void:
			GameManager.current_world = selected_world
			GameManager.current_phase = selected_phase
			GameManager.change_scene(GameManager.SCENE_GAME)
		)


func _is_selected_locked() -> bool:
	if selected_index < 0 or selected_index >= _items.size():
		return true
	var item := _items[selected_index]
	return is_instance_valid(item) and bool(item.get("locked"))


func _play_denied_on_selected() -> void:
	if selected_index < 0 or selected_index >= _items.size():
		return
	var item := _items[selected_index]
	if is_instance_valid(item) and item.has_method("play_denied"):
		# TODO: AUDIO — locked slot denied
		item.play_denied()


func _execute_back() -> void:
	if _mode != SpinMode.IDLE:
		return

	if stage == Stage.PHASE:
		# ZOOM OUT of Select Phase, then World with DIVE OUT (from inside camera)
		_play_zoom_out(func() -> void:
			_enter_world_stage(EnterAnim.DIVE_OUT)
		)
	else:
		# ZOOM OUT of Select World back to main menu
		_play_zoom_out(func() -> void:
			GameManager.go_main_menu()
		)


# ---------------------------------------------------------------------------
# Circle transitions (400ms, ease-in)
# zoom_in  = arrive from far into selection framing
# zoom_out = leave the current circle
# dive_in  = plunge into the north item
# dive_out = come from inside the camera out to selection framing
# ---------------------------------------------------------------------------

func _north_global() -> Vector2:
	return pivot.to_global(Vector2(0.0, -ring_radius))


func _selection_camera_pos() -> Vector2:
	return _north_global() + Vector2(0.0, 40.0)


func _play_zoom_in() -> void:
	## Arrive from far away; bounce only after docking on selection.
	_begin_transition()
	var end_pos := _selection_camera_pos()
	var end_zoom := camera_zoom
	var ring_center := pivot.global_position
	var start_pos := end_pos.lerp(ring_center, zoom_out_pull)

	camera.global_position = start_pos
	camera.zoom = Vector2.ONE * zoom_out_scale
	pivot.scale = Vector2.ONE * zoom_in_start_scale
	pivot.modulate.a = 0.0
	_set_hud_alpha(0.0)

	_run_travel_tween(end_pos, end_zoom)
	_transition_tween.tween_property(pivot, "scale", Vector2.ONE, transition_duration)
	_transition_tween.tween_property(pivot, "modulate:a", 1.0, transition_duration * 0.55)
	_transition_tween.tween_method(_set_hud_alpha, 0.0, 1.0, transition_duration).set_delay(transition_duration * 0.2)
	_schedule_selection_dock_bounce(end_pos, end_zoom, end_pos - start_pos)


func _play_zoom_out(on_done: Callable) -> void:
	## Leave the current circle. No bounce: this is not a selection dock.
	_begin_transition()
	_update_camera()
	var start_pos := camera.global_position
	var ring_center := pivot.global_position
	var end_pos := start_pos.lerp(ring_center, zoom_out_pull)
	var end_zoom := Vector2.ONE * zoom_out_scale

	_run_travel_tween(end_pos, end_zoom)
	_transition_tween.tween_property(pivot, "modulate:a", 0.0, transition_duration)
	_transition_tween.tween_method(_set_hud_alpha, 1.0, 0.0, transition_duration * 0.5)
	_transition_tween.tween_callback(on_done).set_delay(transition_duration)


func _play_dive_in(on_done: Callable) -> void:
	## Plunge into the north item. No bounce: this leaves selection.
	_begin_transition()
	_update_camera()
	var dive_pos := _north_global() + Vector2(0.0, -20.0)
	var dive_z := Vector2.ONE * dive_zoom

	_run_travel_tween(dive_pos, dive_z)
	_transition_tween.tween_property(pivot, "modulate:a", 0.0, transition_duration * 0.85)
	_transition_tween.tween_method(_set_hud_alpha, 1.0, 0.0, transition_duration * 0.35)
	_transition_tween.tween_callback(on_done).set_delay(transition_duration)


func _play_dive_out() -> void:
	## Come from inside the camera; bounce only after docking on selection.
	_begin_transition()
	var end_pos := _selection_camera_pos()
	var end_zoom := camera_zoom
	var start_pos := _north_global() + Vector2(0.0, -20.0)

	camera.global_position = start_pos
	camera.zoom = Vector2.ONE * dive_zoom
	pivot.scale = Vector2.ONE
	pivot.modulate.a = 0.0
	_set_hud_alpha(0.0)

	_run_travel_tween(end_pos, end_zoom)
	_transition_tween.tween_property(pivot, "modulate:a", 1.0, transition_duration * 0.45)
	_transition_tween.tween_method(_set_hud_alpha, 0.0, 1.0, transition_duration).set_delay(transition_duration * 0.25)
	_schedule_selection_dock_bounce(end_pos, end_zoom, end_pos - start_pos)


func _run_travel_tween(end_pos: Vector2, end_zoom: Vector2) -> void:
	_kill_transition()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(camera, "zoom", end_zoom, transition_duration)
	_transition_tween.tween_property(camera, "global_position", end_pos, transition_duration)


func _schedule_selection_dock_bounce(dock_pos: Vector2, dock_zoom: Vector2, travel: Vector2) -> void:
	## Bounce starts only when the travel tween has reached selection rest.
	_transition_tween.tween_callback(
		_play_selection_dock_bounce.bind(dock_pos, dock_zoom, travel)
	).set_delay(transition_duration)


func _play_selection_dock_bounce(dock_pos: Vector2, dock_zoom: Vector2, travel: Vector2) -> void:
	## Overshoot past the parked selection framing, then snap back.
	var dir := travel.normalized() if travel.length_squared() > 1.0 else Vector2.DOWN
	var overshoot_pos := dock_pos + dir * transition_bounce_pixels
	var overshoot_zoom := dock_zoom * (1.0 + transition_bounce_zoom)
	var go := transition_bounce_duration * 0.38
	var back := transition_bounce_duration * 0.62

	_kill_transition()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(camera, "zoom", overshoot_zoom, go)
	_transition_tween.parallel().tween_property(camera, "global_position", overshoot_pos, go)
	_transition_tween.chain()
	_transition_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(camera, "zoom", dock_zoom, back)
	_transition_tween.parallel().tween_property(camera, "global_position", dock_pos, back)
	_transition_tween.tween_callback(_finish_enter_transition)


func _finish_enter_transition() -> void:
	pivot.scale = Vector2.ONE
	pivot.modulate.a = 1.0
	camera.zoom = camera_zoom
	_update_camera()
	_set_hud_alpha(1.0)
	_mode = SpinMode.IDLE


func _begin_transition() -> void:
	_mode = SpinMode.TRANSITION
	_holding = false
	_hold_dir = 0
	_angular_vel = 0.0
	_kill_tween()


func _end_transition_visual_reset() -> void:
	pivot.scale = Vector2.ONE
	pivot.modulate.a = 1.0
	camera.zoom = camera_zoom


func _set_hud_alpha(a: float) -> void:
	for label in _hud_labels:
		if is_instance_valid(label):
			label.modulate.a = a


func _commit_selection() -> void:
	if stage == Stage.WORLD:
		selected_world = selected_index
	else:
		selected_phase = selected_index


func _slot_rotation(index: int) -> float:
	return -float(posmod(index, maxi(_item_count, 1))) * _angle_step


func _index_from_angle(angle: float) -> int:
	if _item_count <= 0:
		return 0
	return posmod(int(round(-angle / _angle_step)), _item_count)


func _angled(from: float, to: float) -> float:
	return fposmod(to - from + PI, TAU) - PI


func _snap_visual_to_selected() -> void:
	carousel.rotation = _slot_rotation(selected_index)
	_angular_vel = 0.0
	_apply_selection_visuals()


func _apply_selection_visuals() -> void:
	for i in _items.size():
		if is_instance_valid(_items[i]) and _items[i].has_method("set_selected"):
			_items[i].set_selected(i == selected_index)


func _update_item_billboards() -> void:
	var inv := -carousel.rotation
	for item in _items:
		if is_instance_valid(item):
			item.rotation = inv


func _update_camera() -> void:
	if _mode == SpinMode.TRANSITION:
		return
	camera.global_position = _selection_camera_pos()


func _refresh_selection_label() -> void:
	if stage == Stage.WORLD:
		var w: Dictionary = worlds[selected_index]
		var lock_tag := "  LOCKED" if bool(w.get("locked", false)) else ""
		selection_label.text = "%d / %d\n%s%s" % [selected_index + 1, worlds.size(), w.name, lock_tag]
	else:
		var w2: Dictionary = worlds[selected_world]
		var phases: Array = w2.phases
		var p: Dictionary = phases[selected_index]
		var lock_tag2 := "  LOCKED" if bool(p.get("locked", false)) else ""
		selection_label.text = "%s\n%d / %d  %s%s" % [
			w2.name, selected_index + 1, phases.size(), p.name, lock_tag2,
		]


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _kill_transition() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _draw_ring_guide() -> void:
	for child in ring_guide.get_children():
		child.queue_free()
	for i in 36:
		var a := float(i) / 36.0 * TAU
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.position = Vector2(cos(a), sin(a)) * ring_radius - dot.size * 0.5
		dot.color = Color(0.305882, 0.803922, 0.768627, 0.35 if i % 3 == 0 else 0.12)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring_guide.add_child(dot)
