extends Control

@onready var title_label: Label = %TitleLabel
@onready var btn_back: Button = %BtnBack


func _ready() -> void:
	var screen_name := GameManager.pending_screen_title
	if screen_name.is_empty():
		screen_name = "Menu"
	title_label.text = screen_name.to_upper()
	btn_back.pressed.connect(_on_back)
	btn_back.grab_focus()


func _on_back() -> void:
	GameManager.go_main_menu()
