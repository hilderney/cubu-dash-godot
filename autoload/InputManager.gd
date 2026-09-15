extends Node

## Applies the exclusive input scheme to Godot's InputMap and virtual pad.

const SAVE_KEY := "input"
const TOUCH_SCENE := preload("res://scenes/ui/TouchControls.tscn")

signal scheme_changed(scheme: InputScheme.Id)
signal bindings_changed

var _scheme: InputScheme.Id = InputScheme.Id.KEYBOARD
var _port: InputPort
var _bindings_by_scheme: Dictionary = {}
var _touch_controls: CanvasLayer
var _virtual_remap: Callable
var _held_virtual: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_port = InputFactory.make(_scheme)
	_load_from_disk()
	_ensure_actions_exist()
	_apply_to_input_map()
	_setup_touch_overlay()
	if not EventBus.scene_changed.is_connected(_on_scene_changed):
		EventBus.scene_changed.connect(_on_scene_changed)
	_refresh_touch_overlay()


func get_scheme() -> InputScheme.Id:
	return _scheme


func get_port() -> InputPort:
	return _port


func get_binding(action: String) -> InputBinding:
	var scheme_map: Dictionary = _bindings_for(_scheme)
	return scheme_map.get(action) as InputBinding


func get_binding_label(action: String) -> String:
	var binding := get_binding(action)
	if binding == null:
		return "—"
	return binding.display_name()


func set_scheme(scheme: InputScheme.Id) -> void:
	if _scheme == scheme:
		return
	_release_all_virtual()
	_scheme = scheme
	_port = InputFactory.make(_scheme)
	_apply_to_input_map()
	_save_to_disk()
	_refresh_touch_overlay()
	scheme_changed.emit(_scheme)
	bindings_changed.emit()


func set_binding(action: String, binding: InputBinding) -> void:
	if binding == null or not InputActions.ALL.has(action):
		return
	var scheme_map: Dictionary = _bindings_for(_scheme)
	for other_action in InputActions.ALL:
		var other := scheme_map.get(other_action) as InputBinding
		if other_action != action and other != null and other.matches(binding):
			scheme_map[other_action] = get_binding(action)
			break
	scheme_map[action] = binding
	_bindings_by_scheme[InputFactory.to_id(_scheme)] = scheme_map
	_apply_to_input_map()
	_save_to_disk()
	bindings_changed.emit()


func reset_current_scheme() -> void:
	_bindings_by_scheme[InputFactory.to_id(_scheme)] = _port.get_default_bindings()
	_apply_to_input_map()
	_save_to_disk()
	bindings_changed.emit()


func begin_virtual_remap(callback: Callable) -> void:
	_virtual_remap = callback
	_refresh_touch_overlay()


func end_virtual_remap() -> void:
	_virtual_remap = Callable()
	_refresh_touch_overlay()


func notify_virtual(virtual_id: String, pressed: bool) -> void:
	if _virtual_remap.is_valid():
		if pressed:
			_virtual_remap.call(virtual_id)
		return
	var action := _action_for_virtual(virtual_id)
	if action.is_empty():
		return
	if pressed:
		_held_virtual[virtual_id] = action
		_press_action(action)
	else:
		_held_virtual.erase(virtual_id)
		_release_action(action)


func is_touch_scheme() -> bool:
	return _scheme == InputScheme.Id.TOUCH


func _ensure_actions_exist() -> void:
	for action in InputActions.ALL:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		var mirrored := InputActions.ui_mirror(action)
		if not mirrored.is_empty() and not InputMap.has_action(mirrored):
			InputMap.add_action(mirrored, 0.5)


func _apply_to_input_map() -> void:
	_ensure_actions_exist()
	for action in InputActions.ALL:
		for mapped in InputActions.mirrored_actions(action):
			InputMap.action_erase_events(mapped)
		var binding := get_binding(action)
		if binding == null or binding.kind == InputBinding.Kind.VIRTUAL:
			continue
		var event := binding.to_event()
		if event == null:
			continue
		InputMap.action_add_event(action, event)
		# Mouse already clicks Control widgets; putting it on ui_accept would double-fire menus.
		var mirrored := InputActions.ui_mirror(action)
		if mirrored.is_empty() or binding.kind == InputBinding.Kind.MOUSE_BUTTON:
			continue
		InputMap.action_add_event(mirrored, event.duplicate(true))


func _bindings_for(scheme: InputScheme.Id) -> Dictionary:
	var id := InputFactory.to_id(scheme)
	if not _bindings_by_scheme.has(id):
		_bindings_by_scheme[id] = InputFactory.make(scheme).get_default_bindings()
	return _bindings_by_scheme[id]


func _action_for_virtual(virtual_id: String) -> String:
	var scheme_map: Dictionary = _bindings_for(_scheme)
	for action in InputActions.ALL:
		var binding := scheme_map.get(action) as InputBinding
		if binding != null and binding.kind == InputBinding.Kind.VIRTUAL and binding.virtual_id == virtual_id:
			return action
	return ""


func _press_action(action: String) -> void:
	for mapped in InputActions.mirrored_actions(action):
		if not Input.is_action_pressed(mapped):
			Input.action_press(mapped)


func _release_action(action: String) -> void:
	for mapped in InputActions.mirrored_actions(action):
		if Input.is_action_pressed(mapped):
			Input.action_release(mapped)


func _release_all_virtual() -> void:
	for virtual_id in _held_virtual.keys():
		_release_action(str(_held_virtual[virtual_id]))
	_held_virtual.clear()


func _setup_touch_overlay() -> void:
	_touch_controls = TOUCH_SCENE.instantiate()
	_touch_controls.visible = false
	add_child(_touch_controls)


func _refresh_touch_overlay() -> void:
	if _touch_controls == null:
		return
	var path := ""
	if get_tree().current_scene != null:
		path = get_tree().current_scene.scene_file_path
	var hide_on_settings := path.ends_with("ControlSettings.tscn") and not _virtual_remap.is_valid()
	_touch_controls.visible = is_touch_scheme() and not hide_on_settings


func _on_scene_changed(_path: String) -> void:
	call_deferred("_refresh_touch_overlay")


func _load_from_disk() -> void:
	var saved: Variant = SaveLoad.get_value(SAVE_KEY, {})
	if saved is not Dictionary:
		_scheme = InputScheme.Id.KEYBOARD
		_port = InputFactory.make(_scheme)
		return
	var data := saved as Dictionary
	_scheme = InputFactory.from_id(str(data.get("scheme", "keyboard")))
	_port = InputFactory.make(_scheme)
	var stored: Variant = data.get("bindings", {})
	if stored is Dictionary:
		_bindings_by_scheme = _deserialize_all(stored)
	for scheme_value in [
		InputScheme.Id.KEYBOARD,
		InputScheme.Id.MIX,
		InputScheme.Id.GAMEPAD,
		InputScheme.Id.TOUCH,
	]:
		_bindings_for(scheme_value)


func _save_to_disk() -> void:
	SaveLoad.set_value(SAVE_KEY, {
		"scheme": InputFactory.to_id(_scheme),
		"bindings": _serialize_all(),
	})


func _serialize_all() -> Dictionary:
	var output := {}
	for scheme_id in _bindings_by_scheme.keys():
		var packed := {}
		var scheme_map: Dictionary = _bindings_by_scheme[scheme_id]
		for action in scheme_map.keys():
			var binding := scheme_map[action] as InputBinding
			if binding != null:
				packed[action] = binding.to_dictionary()
		output[scheme_id] = packed
	return output


func _deserialize_all(stored: Dictionary) -> Dictionary:
	var output := {}
	for scheme_id in stored.keys():
		var packed: Variant = stored[scheme_id]
		if packed is not Dictionary:
			continue
		var scheme_map := {}
		var defaults: Dictionary = InputFactory.make(InputFactory.from_id(str(scheme_id))).get_default_bindings()
		for action in InputActions.ALL:
			var raw: Variant = packed.get(action, null)
			if raw is Dictionary:
				scheme_map[action] = InputBinding.from_dictionary(raw)
			else:
				scheme_map[action] = defaults.get(action)
		output[str(scheme_id)] = scheme_map
	return output
