class_name SavePort
extends RefCounted

## Persistence contract. Domain code depends on this, not on files or clouds.


func save_data(_data: Dictionary) -> void:
	pass


func load_data() -> Dictionary:
	return {}
