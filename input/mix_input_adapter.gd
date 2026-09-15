class_name MixInputAdapter
extends InputPort


func get_scheme() -> InputScheme.Id:
	return InputScheme.Id.MIX


func accepts_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


func get_default_bindings() -> Dictionary:
	return {
		InputActions.LEFT: InputBinding.from_key(KEY_A),
		InputActions.RIGHT: InputBinding.from_key(KEY_D),
		InputActions.UP: InputBinding.from_key(KEY_W),
		InputActions.DOWN: InputBinding.from_key(KEY_S),
		InputActions.BTN_A: InputBinding.from_mouse(MOUSE_BUTTON_LEFT),
		InputActions.BTN_B: InputBinding.from_mouse(MOUSE_BUTTON_RIGHT),
		InputActions.BTN_START: InputBinding.from_key(KEY_ESCAPE),
	}
