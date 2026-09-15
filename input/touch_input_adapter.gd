class_name TouchInputAdapter
extends InputPort


func get_scheme() -> InputScheme.Id:
	return InputScheme.Id.TOUCH


func accepts_event(_event: InputEvent) -> bool:
	return false


func get_default_bindings() -> Dictionary:
	return {
		InputActions.LEFT: InputBinding.from_virtual(InputActions.VIRTUAL_LEFT),
		InputActions.RIGHT: InputBinding.from_virtual(InputActions.VIRTUAL_RIGHT),
		InputActions.UP: InputBinding.from_virtual(InputActions.VIRTUAL_UP),
		InputActions.DOWN: InputBinding.from_virtual(InputActions.VIRTUAL_DOWN),
		InputActions.BTN_A: InputBinding.from_virtual(InputActions.VIRTUAL_A),
		InputActions.BTN_B: InputBinding.from_virtual(InputActions.VIRTUAL_B),
		InputActions.BTN_START: InputBinding.from_virtual(InputActions.VIRTUAL_START),
	}
