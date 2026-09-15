class_name KeyboardInputAdapter
extends InputPort


func get_scheme() -> InputScheme.Id:
	return InputScheme.Id.KEYBOARD


func accepts_event(event: InputEvent) -> bool:
	return event is InputEventKey


func get_default_bindings() -> Dictionary:
	return {
		InputActions.LEFT: InputBinding.from_key(KEY_LEFT),
		InputActions.RIGHT: InputBinding.from_key(KEY_RIGHT),
		InputActions.UP: InputBinding.from_key(KEY_UP),
		InputActions.DOWN: InputBinding.from_key(KEY_DOWN),
		InputActions.BTN_A: InputBinding.from_key(KEY_SPACE),
		InputActions.BTN_B: InputBinding.from_key(KEY_SHIFT),
		InputActions.BTN_START: InputBinding.from_key(KEY_ESCAPE),
	}
