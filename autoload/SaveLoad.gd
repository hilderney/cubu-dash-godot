extends Node

## Save facade. Game code talks to this autoload; the adapter does I/O.

var _port: SavePort
var _data: Dictionary = {}


func _ready() -> void:
	_port = SaveFactory.make_default()
	_data = _port.load_data()


func get_value(key: String, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)


func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	_port.save_data(_data)
