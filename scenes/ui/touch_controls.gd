extends CanvasLayer

## On-screen virtual pad used by the Touch input scheme.


func _ready() -> void:
	layer = 80
	_bind(%BtnLeft, InputActions.VIRTUAL_LEFT)
	_bind(%BtnRight, InputActions.VIRTUAL_RIGHT)
	_bind(%BtnUp, InputActions.VIRTUAL_UP)
	_bind(%BtnDown, InputActions.VIRTUAL_DOWN)
	_bind(%BtnA, InputActions.VIRTUAL_A)
	_bind(%BtnB, InputActions.VIRTUAL_B)
	_bind(%BtnStart, InputActions.VIRTUAL_START)


func _bind(button: BaseButton, virtual_id: String) -> void:
	button.button_down.connect(func() -> void: InputManager.notify_virtual(virtual_id, true))
	button.button_up.connect(func() -> void: InputManager.notify_virtual(virtual_id, false))
