extends Control

## Title screen — Cubu Dash (retro arcade style).

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var menu_box: VBoxContainer = %MenuBox
@onready var btn_start: Button = %BtnStart
@onready var btn_sound: Button = %BtnSound
@onready var btn_graphic: Button = %BtnGraphic
@onready var btn_controls: Button = %BtnControls
@onready var btn_debugger: Button = %BtnDebugger
@onready var version_label: Label = %VersionLabel
@onready var stripe_band: ColorRect = %StripeBand
@onready var cube_a: ColorRect = %CubeA
@onready var cube_b: ColorRect = %CubeB
@onready var cube_c: ColorRect = %CubeC

var _pulse_t: float = 0.0


func _ready() -> void:
	btn_debugger.visible = GameManager.IS_DEV_BUILD
	version_label.text = "DEV BUILD" if GameManager.IS_DEV_BUILD else "v0.1"

	btn_start.pressed.connect(_on_start)
	btn_sound.pressed.connect(_on_sound)
	btn_graphic.pressed.connect(_on_graphic)
	btn_controls.pressed.connect(_on_controls)
	btn_debugger.pressed.connect(_on_debugger)

	_play_intro()
	btn_start.grab_focus()


func _process(delta: float) -> void:
	_pulse_t += delta
	# Diagonal stripe drifting in the background
	stripe_band.position.x = -120.0 + fmod(_pulse_t * 40.0, 140.0)
	# Floating brand cubes
	cube_a.rotation_degrees = sin(_pulse_t * 1.4) * 8.0
	cube_b.rotation_degrees = cos(_pulse_t * 1.1) * 10.0
	cube_c.rotation_degrees = sin(_pulse_t * 1.7 + 1.0) * 6.0
	cube_a.position.y = 120.0 + sin(_pulse_t * 2.0) * 12.0
	cube_b.position.y = 420.0 + cos(_pulse_t * 1.6) * 14.0
	cube_c.position.y = 260.0 + sin(_pulse_t * 1.3 + 0.5) * 10.0


func _play_intro() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	menu_box.modulate.a = 0.0
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2(0.7, 0.7)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(title_label, "modulate:a", 1.0, 0.35)
	tw.tween_property(title_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(subtitle_label, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tw.tween_property(menu_box, "modulate:a", 1.0, 0.35).set_delay(0.25)
	tw.chain().tween_callback(_start_title_pulse)


func _start_title_pulse() -> void:
	title_label.pivot_offset = title_label.size * 0.5
	var bounce := create_tween().set_loops()
	bounce.tween_property(title_label, "scale", Vector2(1.05, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(title_label, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


func _on_start() -> void:
	# TODO: AUDIO — UI confirm start game
	GameManager.go_level_select()


func _on_sound() -> void:
	# TODO: AUDIO — UI open sound settings
	GameManager.open_under_construction("Sound")


func _on_graphic() -> void:
	# TODO: AUDIO — UI open graphic settings
	GameManager.open_under_construction("Graphic")


func _on_controls() -> void:
	# TODO: AUDIO — UI open control settings
	GameManager.go_control_settings()


func _on_debugger() -> void:
	# TODO: AUDIO — UI open debugger
	GameManager.open_under_construction("Debugger")
