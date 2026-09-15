class_name InputPort
extends RefCounted

## Contract for one exclusive input scheme.


func get_scheme() -> InputScheme.Id:
	return InputScheme.Id.KEYBOARD


func accepts_event(_event: InputEvent) -> bool:
	return false


func get_default_bindings() -> Dictionary:
	return {}
