extends Node2D

## One carousel slot (world or phase). Supports locked (gray) and denied press anim.

const LOCKED_ACCENT := Color("6B6B70")
const LOCKED_FILL := Color(0.22, 0.22, 0.24, 1.0)
const DENIED_MS := 0.15
const DENIED_PEAK := 1.18

@onready var visual: ColorRect = $Visual
@onready var border: ColorRect = $Border
@onready var label: Label = $Label
@onready var index_label: Label = $IndexLabel

var item_id: int = 0
var display_name: String = ""
var accent: Color = Color("FF6B35")
var locked: bool = false

var _base_scale: float = 1.0
var _selected: bool = false
var _pulse: float = 0.0
var _denied_mul: float = 1.0
var _denied_tween: Tween


func setup(id: int, title: String, color: Color, is_locked: bool = false) -> void:
	item_id = id
	display_name = title
	accent = color
	locked = is_locked
	label.text = title
	index_label.text = str(id + 1)
	_refresh_colors()


func set_selected(value: bool) -> void:
	_selected = value
	_base_scale = 1.35 if value else 0.85
	modulate.a = 1.0 if value else 0.72
	label.visible = value
	_refresh_colors()


## Press-and-release feel when confirming a locked slot (150 ms).
func play_denied() -> void:
	if _denied_tween != null and _denied_tween.is_valid():
		_denied_tween.kill()
	_denied_mul = 1.0
	var half := DENIED_MS * 0.5
	_denied_tween = create_tween()
	_denied_tween.set_ease(Tween.EASE_OUT)
	_denied_tween.set_trans(Tween.TRANS_QUAD)
	_denied_tween.tween_property(self, "_denied_mul", DENIED_PEAK, half)
	_denied_tween.set_ease(Tween.EASE_IN)
	_denied_tween.tween_property(self, "_denied_mul", 1.0, half)


func _refresh_colors() -> void:
	if locked:
		border.color = LOCKED_ACCENT.lightened(0.25) if _selected else LOCKED_ACCENT
		visual.color = LOCKED_ACCENT.lightened(0.1) if _selected else LOCKED_FILL
		return
	if _selected:
		visual.color = accent.lightened(0.15)
		border.color = Color("FFE66D")
	else:
		visual.color = Color(0.05, 0.12, 0.2, 1.0)
		border.color = accent


func _process(delta: float) -> void:
	_pulse += delta
	var pulse := 1.0 + (sin(_pulse * 6.0) * 0.04 if _selected else 0.0)
	scale = Vector2.ONE * (_base_scale * pulse * _denied_mul)
