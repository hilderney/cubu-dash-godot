extends CanvasLayer

## Dev Tuning Panel (LD-00). PROCESS_MODE_ALWAYS — editable while paused.

const TAB_SIZE := Vector2(72, 28)
const PANEL_SIZE := Vector2(280, 360)

var _game: Node2D
var _player: CharacterBody2D

var _open: bool = false
var _tab: Button
var _panel: PanelContainer
var _target_option: OptionButton
var _fields_box: VBoxContainer
var _field_widgets: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	_set_open(false)


func setup(game: Node2D, player: CharacterBody2D) -> void:
	_game = game
	_player = player
	if _target_option != null:
		_rebuild_target_list()
		_rebuild_fields()


func _build_ui() -> void:
	_tab = Button.new()
	_tab.text = "DEV"
	_tab.custom_minimum_size = TAB_SIZE
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.pressed.connect(_on_tab_pressed)
	add_child(_tab)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := Label.new()
	header.text = "DEV TUNING"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(header)

	_target_option = OptionButton.new()
	_target_option.focus_mode = Control.FOCUS_NONE
	_target_option.item_selected.connect(_on_target_selected)
	root.add_child(_target_option)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	root.add_child(scroll)

	_fields_box = VBoxContainer.new()
	_fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_fields_box)

	_layout_chrome()
	get_viewport().size_changed.connect(_layout_chrome)


func _layout_chrome() -> void:
	var view := get_viewport().get_visible_rect().size
	_tab.position = Vector2(view.x - TAB_SIZE.x - 12.0, 12.0)
	_panel.position = Vector2(view.x - PANEL_SIZE.x - 12.0, 12.0 + TAB_SIZE.y + 6.0)


func _on_tab_pressed() -> void:
	_set_open(not _open)


func _set_open(value: bool) -> void:
	_open = value
	_panel.visible = _open
	_tab.text = "DEV ▾" if _open else "DEV"
	if _open:
		_rebuild_fields()


func _rebuild_target_list() -> void:
	_target_option.clear()
	if _player != null:
		_target_option.add_item("Player")
	if _game != null:
		_target_option.add_item("Game")
	if _target_option.item_count > 0:
		_target_option.select(0)


func _on_target_selected(_index: int) -> void:
	_rebuild_fields()


func _current_target() -> Object:
	if _target_option == null or _target_option.item_count == 0:
		return null
	var label := _target_option.get_item_text(_target_option.selected)
	match label:
		"Player":
			return _player
		"Game":
			return _game
		_:
			return null


func _tunables_for(target: Object) -> Array:
	# Each entry: { "prop": String, "min": float, "max": float, "step": float }
	if target == _player:
		return [
			{"prop": "jump_force", "min": -1200.0, "max": -100.0, "step": 10.0},
			{"prop": "gravity", "min": 200.0, "max": 3000.0, "step": 10.0},
			{"prop": "dash_duration", "min": 0.05, "max": 1.0, "step": 0.01},
			{"prop": "max_jumps", "min": 1.0, "max": 5.0, "step": 1.0},
		]
	if target == _game:
		return [
			{"prop": "base_scroll_speed", "min": 50.0, "max": 900.0, "step": 5.0},
			{"prop": "dash_scroll_multiplier", "min": 1.0, "max": 5.0, "step": 0.05},
			{"prop": "camera_look_ahead", "min": 0.0, "max": 800.0, "step": 10.0},
		]
	return []


func _rebuild_fields() -> void:
	for child in _fields_box.get_children():
		child.queue_free()
	_field_widgets.clear()

	var target := _current_target()
	if target == null:
		return

	for entry in _tunables_for(target):
		var prop: String = entry.prop
		if not prop in target:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_fields_box.add_child(row)

		var name_label := Label.new()
		name_label.text = prop
		name_label.custom_minimum_size = Vector2(140, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var spin := SpinBox.new()
		spin.min_value = entry.min
		spin.max_value = entry.max
		spin.step = entry.step
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.focus_mode = Control.FOCUS_CLICK
		spin.value = float(target.get(prop))
		spin.value_changed.connect(_on_value_changed.bind(target, prop))
		row.add_child(spin)
		_field_widgets.append(spin)


func _on_value_changed(value: float, target: Object, prop: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	if prop == "max_jumps":
		target.set(prop, int(round(value)))
	else:
		target.set(prop, value)
	if target == _game and prop == "base_scroll_speed":
		_sync_game_scroll_speed()


func _sync_game_scroll_speed() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	if _player != null and bool(_player.get("is_dashing")):
		_game.set("_scroll_speed", _game.base_scroll_speed * _game.dash_scroll_multiplier)
	else:
		_game.set("_scroll_speed", _game.base_scroll_speed)
