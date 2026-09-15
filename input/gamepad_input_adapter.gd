class_name GamepadInputAdapter
extends InputPort


func get_scheme() -> InputScheme.Id:
	return InputScheme.Id.GAMEPAD


func accepts_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func get_default_bindings() -> Dictionary:
	return {
		InputActions.LEFT: InputBinding.from_joy_button(JOY_BUTTON_DPAD_LEFT),
		InputActions.RIGHT: InputBinding.from_joy_button(JOY_BUTTON_DPAD_RIGHT),
		InputActions.UP: InputBinding.from_joy_button(JOY_BUTTON_DPAD_UP),
		InputActions.DOWN: InputBinding.from_joy_button(JOY_BUTTON_DPAD_DOWN),
		InputActions.BTN_A: InputBinding.from_joy_button(JOY_BUTTON_A),
		InputActions.BTN_B: InputBinding.from_joy_button(JOY_BUTTON_B),
		InputActions.BTN_START: InputBinding.from_joy_button(JOY_BUTTON_START),
	}
