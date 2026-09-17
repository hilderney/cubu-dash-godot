extends CanvasLayer

## In-run pause overlay. Start toggles; Resume button continues; Main Menu leaves.

@onready var btn_resume: Button = %BtnResume
@onready var btn_menu: Button = %BtnMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 50
	btn_resume.pressed.connect(resume_game)
	btn_menu.pressed.connect(_on_main_menu)


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed(InputActions.BTN_START):
		return
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	get_tree().paused = true
	visible = true
	btn_resume.grab_focus()


func resume_game() -> void:
	get_tree().paused = false
	visible = false


func _on_main_menu() -> void:
	get_tree().paused = false
	visible = false
	GameManager.end_run()
	GameManager.go_main_menu()
