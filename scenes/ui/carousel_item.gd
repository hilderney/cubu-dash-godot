extends Node2D

## Um slot do carrossel (mundo ou fase).

@onready var visual: ColorRect = $Visual
@onready var border: ColorRect = $Border
@onready var label: Label = $Label
@onready var index_label: Label = $IndexLabel

var item_id: int = 0
var display_name: String = ""
var accent: Color = Color("FF6B35")

var _base_scale: float = 1.0
var _selected: bool = false
var _pulse: float = 0.0


func setup(id: int, title: String, color: Color) -> void:
	item_id = id
	display_name = title
	accent = color
	label.text = title
	index_label.text = str(id + 1)
	border.color = accent
	visual.color = Color(0.05, 0.12, 0.2, 1.0)


func set_selected(value: bool) -> void:
	_selected = value
	_base_scale = 1.35 if value else 0.85
	modulate.a = 1.0 if value else 0.72
	label.visible = value
	if value:
		visual.color = accent.lightened(0.15)
		border.color = Color("FFE66D")
	else:
		visual.color = Color(0.05, 0.12, 0.2, 1.0)
		border.color = accent


func _process(delta: float) -> void:
	_pulse += delta
	var pulse := 1.0 + (sin(_pulse * 6.0) * 0.04 if _selected else 0.0)
	scale = Vector2.ONE * (_base_scale * pulse)
