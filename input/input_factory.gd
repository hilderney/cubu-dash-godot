class_name InputFactory
extends RefCounted

## Wires the InputPort adapter for the selected exclusive scheme.


static func make(scheme: InputScheme.Id) -> InputPort:
	match scheme:
		InputScheme.Id.MIX:
			return MixInputAdapter.new()
		InputScheme.Id.GAMEPAD:
			return GamepadInputAdapter.new()
		InputScheme.Id.TOUCH:
			return TouchInputAdapter.new()
		_:
			return KeyboardInputAdapter.new()


static func label(scheme: InputScheme.Id) -> String:
	match scheme:
		InputScheme.Id.KEYBOARD:
			return "KEYBOARD"
		InputScheme.Id.MIX:
			return "KEYBOARD + MOUSE"
		InputScheme.Id.GAMEPAD:
			return "GAMEPAD"
		InputScheme.Id.TOUCH:
			return "TOUCH"
		_:
			return "KEYBOARD"


static func to_id(scheme: InputScheme.Id) -> String:
	match scheme:
		InputScheme.Id.MIX:
			return "mix"
		InputScheme.Id.GAMEPAD:
			return "gamepad"
		InputScheme.Id.TOUCH:
			return "touch"
		_:
			return "keyboard"


static func from_id(id: String) -> InputScheme.Id:
	match id:
		"mix":
			return InputScheme.Id.MIX
		"gamepad":
			return InputScheme.Id.GAMEPAD
		"touch":
			return InputScheme.Id.TOUCH
		_:
			return InputScheme.Id.KEYBOARD


static func cycle(scheme: InputScheme.Id, direction: int) -> InputScheme.Id:
	var next := wrapi(int(scheme) + direction, 0, 4)
	return next as InputScheme.Id


static func is_mobile_platform() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")


static func default_scheme() -> InputScheme.Id:
	if is_mobile_platform():
		return InputScheme.Id.TOUCH
	return InputScheme.Id.KEYBOARD
