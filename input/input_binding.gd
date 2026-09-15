class_name InputBinding
extends RefCounted

## One physical (or virtual) control bound to a single action.

enum Kind { KEY, MOUSE_BUTTON, JOY_BUTTON, JOY_AXIS, VIRTUAL }

var kind: Kind = Kind.KEY
var physical_keycode: int = 0
var mouse_button: int = 0
var joy_button: int = 0
var joy_axis: int = 0
var axis_sign: int = 1
var virtual_id: String = ""


static func from_key(keycode: int) -> InputBinding:
	var binding := InputBinding.new()
	binding.kind = Kind.KEY
	binding.physical_keycode = keycode
	return binding


static func from_mouse(button_index: int) -> InputBinding:
	var binding := InputBinding.new()
	binding.kind = Kind.MOUSE_BUTTON
	binding.mouse_button = button_index
	return binding


static func from_joy_button(button_index: int) -> InputBinding:
	var binding := InputBinding.new()
	binding.kind = Kind.JOY_BUTTON
	binding.joy_button = button_index
	return binding


static func from_joy_axis(axis: int, sign_value: int) -> InputBinding:
	var binding := InputBinding.new()
	binding.kind = Kind.JOY_AXIS
	binding.joy_axis = axis
	binding.axis_sign = 1 if sign_value >= 0 else -1
	return binding


static func from_virtual(id: String) -> InputBinding:
	var binding := InputBinding.new()
	binding.kind = Kind.VIRTUAL
	binding.virtual_id = id
	return binding


static func from_event(event: InputEvent) -> InputBinding:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode
		if code == KEY_NONE:
			code = key_event.keycode
		if code == KEY_NONE:
			return null
		return from_key(code)
	if event is InputEventMouseButton:
		return from_mouse((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return from_joy_button((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < 0.5:
			return null
		return from_joy_axis(motion.axis, 1 if motion.axis_value > 0.0 else -1)
	return null


static func from_dictionary(data: Dictionary) -> InputBinding:
	var kind_name := str(data.get("kind", "key"))
	match kind_name:
		"mouse_button":
			return from_mouse(int(data.get("button_index", MOUSE_BUTTON_LEFT)))
		"joy_button":
			return from_joy_button(int(data.get("button_index", JOY_BUTTON_A)))
		"joy_axis":
			return from_joy_axis(int(data.get("axis", JOY_AXIS_LEFT_X)), int(data.get("axis_sign", -1)))
		"virtual":
			return from_virtual(str(data.get("virtual_id", InputActions.VIRTUAL_A)))
		_:
			return from_key(int(data.get("physical_keycode", KEY_SPACE)))


func to_dictionary() -> Dictionary:
	match kind:
		Kind.MOUSE_BUTTON:
			return {"kind": "mouse_button", "button_index": mouse_button}
		Kind.JOY_BUTTON:
			return {"kind": "joy_button", "button_index": joy_button}
		Kind.JOY_AXIS:
			return {"kind": "joy_axis", "axis": joy_axis, "axis_sign": axis_sign}
		Kind.VIRTUAL:
			return {"kind": "virtual", "virtual_id": virtual_id}
		_:
			return {"kind": "key", "physical_keycode": physical_keycode}


func to_event() -> InputEvent:
	match kind:
		Kind.KEY:
			var key := InputEventKey.new()
			key.physical_keycode = physical_keycode as Key
			key.keycode = physical_keycode as Key
			key.pressed = true
			key.device = -1
			return key
		Kind.MOUSE_BUTTON:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = mouse_button as MouseButton
			mouse.pressed = true
			mouse.device = -1
			return mouse
		Kind.JOY_BUTTON:
			var button := InputEventJoypadButton.new()
			button.button_index = joy_button as JoyButton
			button.pressed = true
			button.device = -1
			return button
		Kind.JOY_AXIS:
			var axis := InputEventJoypadMotion.new()
			axis.axis = joy_axis as JoyAxis
			axis.axis_value = float(axis_sign)
			axis.device = -1
			return axis
		_:
			return null


func matches(other: InputBinding) -> bool:
	if other == null or kind != other.kind:
		return false
	match kind:
		Kind.KEY:
			return physical_keycode == other.physical_keycode
		Kind.MOUSE_BUTTON:
			return mouse_button == other.mouse_button
		Kind.JOY_BUTTON:
			return joy_button == other.joy_button
		Kind.JOY_AXIS:
			return joy_axis == other.joy_axis and axis_sign == other.axis_sign
		Kind.VIRTUAL:
			return virtual_id == other.virtual_id
		_:
			return false


func display_name() -> String:
	match kind:
		Kind.KEY:
			return _key_name(physical_keycode)
		Kind.MOUSE_BUTTON:
			return _mouse_name(mouse_button)
		Kind.JOY_BUTTON:
			return _joy_button_name(joy_button)
		Kind.JOY_AXIS:
			return _joy_axis_name(joy_axis, axis_sign)
		Kind.VIRTUAL:
			return _virtual_name(virtual_id)
		_:
			return "?"


static func _key_name(keycode: int) -> String:
	match keycode:
		KEY_LEFT:
			return "LEFT ARROW"
		KEY_RIGHT:
			return "RIGHT ARROW"
		KEY_UP:
			return "UP ARROW"
		KEY_DOWN:
			return "DOWN ARROW"
		KEY_ESCAPE:
			return "ESC"
		KEY_SHIFT:
			return "SHIFT"
		KEY_CTRL:
			return "CTRL"
		KEY_ALT:
			return "ALT"
		KEY_SPACE:
			return "SPACE"
		KEY_ENTER:
			return "ENTER"
		KEY_TAB:
			return "TAB"
		_:
			var label := OS.get_keycode_string(keycode as Key)
			return label.to_upper() if not label.is_empty() else "KEY %d" % keycode


static func _mouse_name(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "MOUSE LEFT"
		MOUSE_BUTTON_RIGHT:
			return "MOUSE RIGHT"
		MOUSE_BUTTON_MIDDLE:
			return "MOUSE MIDDLE"
		MOUSE_BUTTON_WHEEL_UP:
			return "WHEEL UP"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "WHEEL DOWN"
		MOUSE_BUTTON_XBUTTON1:
			return "MOUSE 4"
		MOUSE_BUTTON_XBUTTON2:
			return "MOUSE 5"
		_:
			return "MOUSE %d" % button_index


static func _joy_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "PAD A"
		JOY_BUTTON_B:
			return "PAD B"
		JOY_BUTTON_X:
			return "PAD X"
		JOY_BUTTON_Y:
			return "PAD Y"
		JOY_BUTTON_BACK:
			return "PAD BACK"
		JOY_BUTTON_GUIDE:
			return "PAD GUIDE"
		JOY_BUTTON_START:
			return "PAD START"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return "DPAD UP"
		JOY_BUTTON_DPAD_DOWN:
			return "DPAD DOWN"
		JOY_BUTTON_DPAD_LEFT:
			return "DPAD LEFT"
		JOY_BUTTON_DPAD_RIGHT:
			return "DPAD RIGHT"
		_:
			return "PAD BTN %d" % button_index


static func _joy_axis_name(axis: int, sign_value: int) -> String:
	var negative := sign_value < 0
	match axis:
		JOY_AXIS_LEFT_X:
			return "L-STICK LEFT" if negative else "L-STICK RIGHT"
		JOY_AXIS_LEFT_Y:
			return "L-STICK UP" if negative else "L-STICK DOWN"
		JOY_AXIS_RIGHT_X:
			return "R-STICK LEFT" if negative else "R-STICK RIGHT"
		JOY_AXIS_RIGHT_Y:
			return "R-STICK UP" if negative else "R-STICK DOWN"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		_:
			return "AXIS %d%s" % [axis, "-" if negative else "+"]


static func _virtual_name(id: String) -> String:
	match id:
		InputActions.VIRTUAL_LEFT:
			return "ON-SCREEN LEFT"
		InputActions.VIRTUAL_RIGHT:
			return "ON-SCREEN RIGHT"
		InputActions.VIRTUAL_UP:
			return "ON-SCREEN UP"
		InputActions.VIRTUAL_DOWN:
			return "ON-SCREEN DOWN"
		InputActions.VIRTUAL_A:
			return "ON-SCREEN A"
		InputActions.VIRTUAL_B:
			return "ON-SCREEN B"
		InputActions.VIRTUAL_START:
			return "ON-SCREEN START"
		_:
			return id.to_upper()
