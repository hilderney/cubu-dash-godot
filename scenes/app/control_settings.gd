extends Control

## Remap screen for the exclusive input scheme and its seven actions.

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

@onready var scheme_label: Label = %SchemeLabel
@onready var actions_box: VBoxContainer = %ActionsBox
@onready var hint_label: Label = %HintLabel
@onready var btn_scheme_prev: Button = %BtnSchemePrev
@onready var btn_scheme_next: Button = %BtnSchemeNext
@onready var btn_reset: Button = %BtnReset
@onready var btn_back: Button = %BtnBack

var _bind_labels: Dictionary = {}
var _change_buttons: Dictionary = {}
var _listening_action: String = ""
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_pressed: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_build_action_rows()
	btn_scheme_prev.pressed.connect(func() -> void: _cycle_scheme(-1))
	btn_scheme_next.pressed.connect(func() -> void: _cycle_scheme(1))
	btn_reset.pressed.connect(_on_reset)
	btn_back.pressed.connect(_on_back)
	btn_scheme_prev.focus_neighbor_left = btn_scheme_prev.get_path()
	btn_scheme_prev.focus_neighbor_right = btn_scheme_next.get_path()
	btn_scheme_next.focus_neighbor_left = btn_scheme_prev.get_path()
	btn_scheme_next.focus_neighbor_right = btn_scheme_next.get_path()
	if not InputManager.bindings_changed.is_connected(_refresh_labels):
		InputManager.bindings_changed.connect(_refresh_labels)
	if not InputManager.scheme_changed.is_connected(_on_scheme_changed):
		InputManager.scheme_changed.connect(_on_scheme_changed)
	_refresh_labels()
	_update_hint()
	btn_scheme_next.grab_focus()


func _exit_tree() -> void:
	_stop_listen()
	if InputManager.bindings_changed.is_connected(_refresh_labels):
		InputManager.bindings_changed.disconnect(_refresh_labels)
	if InputManager.scheme_changed.is_connected(_on_scheme_changed):
		InputManager.scheme_changed.disconnect(_on_scheme_changed)


func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		if event.is_echo():
			return
		if event.is_action_pressed(InputActions.LEFT):
			_press_scheme_button(btn_scheme_prev)
		elif event.is_action_pressed(InputActions.RIGHT):
			_press_scheme_button(btn_scheme_next)
		elif event.is_action_pressed(InputActions.BTN_B) or event.is_action_pressed(InputActions.BTN_START):
			_on_back()
			get_viewport().set_input_as_handled()
		return
	if _should_ignore_capture(event):
		return
	if not InputManager.get_port().accepts_event(event):
		return
	if event.is_echo():
		return
	if not event.is_pressed():
		return
	var binding := InputBinding.from_event(event)
	if binding == null:
		return
	InputManager.set_binding(_listening_action, binding)
	# TODO: AUDIO — input binding captured
	_stop_listen()
	get_viewport().set_input_as_handled()


func _press_scheme_button(button: Button) -> void:
	button.grab_focus()
	button.pressed.emit()
	get_viewport().set_input_as_handled()


func _cycle_scheme(direction: int) -> void:
	_stop_listen()
	# TODO: AUDIO — input scheme changed
	InputManager.set_scheme(InputFactory.cycle(InputManager.get_scheme(), direction))


func _on_scheme_changed(_scheme: InputScheme.Id) -> void:
	_refresh_labels()
	_update_hint()


func _on_reset() -> void:
	_stop_listen()
	# TODO: AUDIO — input bindings reset
	InputManager.reset_current_scheme()


func _on_back() -> void:
	_stop_listen()
	# TODO: AUDIO — UI back from control settings
	GameManager.go_main_menu()


func _on_change_pressed(action: String) -> void:
	if _listening_action == action:
		_stop_listen()
		return
	_start_listen(action)


func _start_listen(action: String) -> void:
	_stop_listen()
	_listening_action = action
	if InputManager.is_touch_scheme():
		InputManager.begin_virtual_remap(_on_virtual_captured)
	_refresh_labels()
	_update_hint()


func _stop_listen() -> void:
	_listening_action = ""
	InputManager.end_virtual_remap()
	_refresh_labels()
	_update_hint()


func _on_virtual_captured(virtual_id: String) -> void:
	if _listening_action.is_empty():
		return
	InputManager.set_binding(_listening_action, InputBinding.from_virtual(virtual_id))
	# TODO: AUDIO — input binding captured
	_stop_listen()


func _should_ignore_capture(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered is BaseButton:
			return true
	return false


func _refresh_labels(_unused: Variant = null) -> void:
	scheme_label.text = InputFactory.label(InputManager.get_scheme())
	for action in InputActions.ALL:
		var label := _bind_labels.get(action) as Label
		var button := _change_buttons.get(action) as Button
		if label == null or button == null:
			continue
		if _listening_action == action:
			label.text = "WAITING..."
			button.text = "CANCEL"
		else:
			label.text = InputManager.get_binding_label(action)
			button.text = "CHANGE"


func _update_hint() -> void:
	if not _listening_action.is_empty():
		if InputManager.is_touch_scheme():
			hint_label.text = "TAP AN ON-SCREEN BUTTON"
		else:
			hint_label.text = "PRESS A CONTROL FOR THIS ACTION"
		return
	hint_label.text = "LEFT RIGHT CHANGE TYPE   B BACK"


func _build_action_rows() -> void:
	for child in actions_box.get_children():
		child.queue_free()
	_bind_labels.clear()
	_change_buttons.clear()
	for action in InputActions.ALL:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = InputActions.display_label(action)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_override("font", FONT)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color("FFE66D"))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var bind_label := Label.new()
		bind_label.custom_minimum_size = Vector2(220, 0)
		bind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bind_label.add_theme_font_override("font", FONT)
		bind_label.add_theme_font_size_override("font_size", 10)
		bind_label.add_theme_color_override("font_color", Color("4ECDC4"))
		bind_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		bind_label.clip_text = true

		var change_btn := Button.new()
		change_btn.custom_minimum_size = Vector2(140, 40)
		change_btn.text = "CHANGE"
		change_btn.add_theme_font_override("font", FONT)
		change_btn.add_theme_font_size_override("font_size", 10)
		change_btn.add_theme_color_override("font_color", Color("FFE66D"))
		change_btn.add_theme_color_override("font_hover_color", Color("082032"))
		change_btn.add_theme_color_override("font_pressed_color", Color("082032"))
		change_btn.add_theme_color_override("font_focus_color", Color("FFE66D"))
		change_btn.add_theme_stylebox_override("normal", _style_normal)
		change_btn.add_theme_stylebox_override("hover", _style_hover)
		change_btn.add_theme_stylebox_override("pressed", _style_pressed)
		change_btn.add_theme_stylebox_override("focus", _style_hover)
		change_btn.pressed.connect(_on_change_pressed.bind(action))

		row.add_child(name_label)
		row.add_child(bind_label)
		row.add_child(change_btn)
		actions_box.add_child(row)
		_bind_labels[action] = bind_label
		_change_buttons[action] = change_btn


func _build_styles() -> void:
	_style_normal = _make_style(Color("082032"), Color("4ECDC4"))
	_style_hover = _make_style(Color("FF6B35"), Color("FFE66D"))
	_style_pressed = _make_style(Color("FFE66D"), Color("082032"))


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_offset = Vector2(3, 3)
	return style
