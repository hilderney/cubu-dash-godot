extends Node2D

## Seleção circular estilo relógio: World -> Phase.
## Item selecionado sempre ao NORTE (12h). Esquerda/direita gira o anel.

enum Stage { WORLD, PHASE }

const ITEM_SCENE := preload("res://scenes/ui/CarouselItem.tscn")

## Paleta ousada por mundo (repete se precisar).
const WORLD_COLORS: Array[Color] = [
	Color("FF6B35"), Color("FFE66D"), Color("4ECDC4"), Color("FF8C42"),
	Color("2EC4B6"), Color("E71D36"), Color("FF9F1C"), Color("7BDFF2"),
	Color("F15BB5"), Color("00F5D4"), Color("FEE440"), Color("9B5DE5"),
]

@export var ring_radius: float = 420.0
@export var spin_step_duration: float = 0.22
@export var hold_initial_delay: float = 0.26
@export var hold_step_interval: float = 0.16
@export var camera_zoom: Vector2 = Vector2(1.15, 1.15)

@onready var camera: Camera2D = %Camera2D
@onready var pivot: Node2D = %Pivot
@onready var carousel: Node2D = %Carousel
@onready var ring_guide: Node2D = %RingGuide
@onready var stage_label: Label = %StageLabel
@onready var selection_label: Label = %SelectionLabel
@onready var hint_label: Label = %HintLabel
@onready var hub: Node2D = %Hub

var worlds: Array[Dictionary] = []
var stage: Stage = Stage.WORLD
var selected_world: int = 0
var selected_phase: int = 0
var selected_index: int = 0

var _items: Array[Node2D] = []
var _item_count: int = 0
var _angle_step: float = 0.0
var _target_rotation: float = 0.0
var _spin_tween: Tween

var _hold_dir: int = 0
var _hold_timer: float = 0.0
var _hold_started: bool = false


func _ready() -> void:
	_build_world_data()
	camera.zoom = camera_zoom
	_enter_world_stage()
	_draw_ring_guide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_back()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		_on_confirm()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_right"):
		_begin_hold(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_begin_hold(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_right") and _hold_dir == 1:
		_end_hold()
	elif event.is_action_released("ui_left") and _hold_dir == -1:
		_end_hold()


func _process(delta: float) -> void:
	_update_item_billboards()
	_update_camera()
	_update_hold(delta)
	hub.rotation += delta * 0.35


func _build_world_data() -> void:
	worlds.clear()
	var world_names := [
		"NEON CUBES", "PIXEL PEAKS", "VOLT VALLEY", "CANDY CORE",
		"ASTRO ALLEY", "EMBER EDGE", "GLITCH GULF", "FROST FORGE",
		"SUNKEN SYNC", "HYPER HIVE", "VOID VISTA", "CHRONO CIRCUIT",
	]
	for i in world_names.size():
		var phase_count := 8 + (i % 5) # 8..12 fases
		var phases: Array[Dictionary] = []
		for p in phase_count:
			phases.append({
				"name": "PHASE %d-%d" % [i + 1, p + 1],
				"id": p,
			})
		worlds.append({
			"name": world_names[i],
			"id": i,
			"color": WORLD_COLORS[i % WORLD_COLORS.size()],
			"phases": phases,
		})


func _enter_world_stage() -> void:
	stage = Stage.WORLD
	selected_index = selected_world
	stage_label.text = "SELECT WORLD"
	hint_label.text = "← → GIRAR   ENTER CONFIRMAR   ESC VOLTAR"
	_rebuild_carousel(_world_entries())
	_snap_to_selected(false)
	_refresh_selection_label()


func _enter_phase_stage() -> void:
	stage = Stage.PHASE
	selected_phase = 0
	selected_index = 0
	var world: Dictionary = worlds[selected_world]
	stage_label.text = "SELECT PHASE"
	hint_label.text = "← → GIRAR   ENTER JOGAR   ESC MUNDOS"
	_rebuild_carousel(_phase_entries(world))
	_snap_to_selected(false)
	_refresh_selection_label()


func _world_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in worlds:
		out.append({
			"id": w.id,
			"name": w.name,
			"color": w.color,
		})
	return out


func _phase_entries(world: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var phases: Array = world.phases
	for p in phases:
		out.append({
			"id": p.id,
			"name": p.name,
			"color": world.color,
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
		item.setup(entry.id, entry.name, entry.color)

		# 12h = -PI/2; sentido horário como relógio (1, 2, 3...)
		var angle := -PI / 2.0 + float(i) * _angle_step
		item.position = Vector2(cos(angle), sin(angle)) * ring_radius
		_items.append(item)

	_apply_selection_visuals()


func _begin_hold(dir: int) -> void:
	_hold_dir = dir
	_hold_started = true
	_hold_timer = 0.0
	_step_selection(dir)


func _end_hold() -> void:
	_hold_dir = 0
	_hold_started = false
	_hold_timer = 0.0


func _update_hold(delta: float) -> void:
	if _hold_dir == 0:
		return

	# Continua se a tecla ainda está pressionada
	var still_holding := (
		(_hold_dir == 1 and Input.is_action_pressed("ui_right"))
		or (_hold_dir == -1 and Input.is_action_pressed("ui_left"))
	)
	if not still_holding:
		_end_hold()
		return

	_hold_timer += delta
	var threshold := hold_initial_delay if _hold_started else hold_step_interval
	# Após o primeiro passo, usa intervalo curto constante
	if _hold_timer >= threshold:
		_hold_timer = 0.0
		_hold_started = false
		_step_selection(_hold_dir)


func _step_selection(dir: int) -> void:
	if _item_count <= 0:
		return
	# dir +1 = direita = próximo no relógio (12 -> 1)
	selected_index = posmod(selected_index + dir, _item_count)
	if stage == Stage.WORLD:
		selected_world = selected_index
	else:
		selected_phase = selected_index
	_animate_to_selected()
	_apply_selection_visuals()
	_refresh_selection_label()


func _animate_to_selected() -> void:
	# Rotaciona o anel para o item ir ao norte
	_target_rotation = -float(selected_index) * _angle_step
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()

	var duration := hold_step_interval if _hold_dir != 0 else spin_step_duration
	_spin_tween = create_tween()
	if _hold_dir != 0:
		_spin_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_spin_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spin_tween.tween_property(
		carousel,
		"rotation",
		_shortest_angle(carousel.rotation, _target_rotation),
		duration
	)


func _snap_to_selected(animate: bool) -> void:
	_target_rotation = -float(selected_index) * _angle_step
	if animate:
		_animate_to_selected()
	else:
		carousel.rotation = _target_rotation
	_apply_selection_visuals()


func _shortest_angle(from: float, to: float) -> float:
	## Evita giro longo no wrap (ex.: 11 -> 0).
	var delta := fposmod(to - from + PI, TAU) - PI
	return from + delta


func _apply_selection_visuals() -> void:
	for i in _items.size():
		if is_instance_valid(_items[i]) and _items[i].has_method("set_selected"):
			_items[i].set_selected(i == selected_index)


func _update_item_billboards() -> void:
	# Labels/cubos ficam “em pé” enquanto o anel gira
	var inv := -carousel.rotation
	for item in _items:
		if is_instance_valid(item):
			item.rotation = inv


func _update_camera() -> void:
	# Norte fixo no espaço do pivô (slot 12h), não gira com o carrossel
	var north_global := pivot.to_global(Vector2(0.0, -ring_radius))
	camera.global_position = north_global + Vector2(0.0, 40.0)


func _refresh_selection_label() -> void:
	if stage == Stage.WORLD:
		var w: Dictionary = worlds[selected_world]
		selection_label.text = "%d / %d\n%s" % [selected_world + 1, worlds.size(), w.name]
	else:
		var w2: Dictionary = worlds[selected_world]
		var phases: Array = w2.phases
		var p: Dictionary = phases[selected_phase]
		selection_label.text = "%s\n%d / %d  %s" % [w2.name, selected_phase + 1, phases.size(), p.name]


func _on_confirm() -> void:
	if stage == Stage.WORLD:
		selected_world = selected_index
		_enter_phase_stage()
	else:
		selected_phase = selected_index
		GameManager.current_world = selected_world
		GameManager.current_phase = selected_phase
		GameManager.start_run()
		GameManager.change_scene(GameManager.SCENE_GAME)


func _on_back() -> void:
	if stage == Stage.PHASE:
		_enter_world_stage()
	else:
		GameManager.go_main_menu()


func _draw_ring_guide() -> void:
	# Pontinhos no anel para reforçar a metáfora do relógio
	for child in ring_guide.get_children():
		child.queue_free()
	var dots := 36
	for i in dots:
		var a := float(i) / float(dots) * TAU
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.position = Vector2(cos(a), sin(a)) * ring_radius - dot.size * 0.5
		dot.color = Color(0.305882, 0.803922, 0.768627, 0.35 if i % 3 == 0 else 0.12)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring_guide.add_child(dot)
