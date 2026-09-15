extends Node

## Global run state (stage, coins, records) and scene navigation.

## true = development build (shows Debugger in the main menu).
## Set to false for release builds.
const IS_DEV_BUILD: bool = true

const SCENE_MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const SCENE_GAME := "res://scenes/Game.tscn"
const SCENE_UNDER_CONSTRUCTION := "res://scenes/ui/UnderConstruction.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const SCENE_SOUND := "res://scenes/ui/UnderConstruction.tscn"
const SCENE_GRAPHIC := "res://scenes/ui/UnderConstruction.tscn"
const SCENE_CONTROLS := "res://scenes/ui/ControlSettings.tscn"
const SCENE_DEBUGGER := "res://scenes/ui/UnderConstruction.tscn"

var current_world: int = 0
var current_phase: int = 0
var coins: int = 0
var records: Dictionary = {}
var is_running: bool = false

## Title shown on the under-construction placeholder screen.
var pending_screen_title: String = ""


func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	EventBus.scene_changed.emit(path)


func open_under_construction(title: String) -> void:
	pending_screen_title = title
	change_scene(SCENE_UNDER_CONSTRUCTION)


func go_main_menu() -> void:
	change_scene(SCENE_MAIN_MENU)


func go_control_settings() -> void:
	change_scene(SCENE_CONTROLS)


func go_level_select() -> void:
	change_scene(SCENE_LEVEL_SELECT)


func start_run() -> void:
	is_running = true
	InputManager.sync_input_map()


func end_run() -> void:
	is_running = false
	InputManager.sync_input_map()


func add_coins(amount: int) -> void:
	coins += amount
	EventBus.coin_collected.emit(amount)
