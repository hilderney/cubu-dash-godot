class_name MixInputAdapter
extends InputPort


func get_scheme() -> InputScheme.Id:
	return InputScheme.Id.MIX


func accepts_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


func get_default_bindings() -> Dictionary:
	return {
		InputActions.LEFT: [
			InputBinding.from_key(KEY_A),
			InputBinding.from_key(KEY_LEFT),
		],
		InputActions.RIGHT: [
			InputBinding.from_key(KEY_D),
			InputBinding.from_key(KEY_RIGHT),
		],
		InputActions.UP: [
			InputBinding.from_key(KEY_W),
			InputBinding.from_key(KEY_UP),
		],
		InputActions.DOWN: [
			InputBinding.from_key(KEY_S),
			InputBinding.from_key(KEY_DOWN),
		],
		InputActions.BTN_A: InputBinding.from_mouse(MOUSE_BUTTON_RIGHT),
		InputActions.BTN_B: InputBinding.from_mouse(MOUSE_BUTTON_LEFT),
		InputActions.BTN_START: InputBinding.from_key(KEY_ESCAPE),
	}
