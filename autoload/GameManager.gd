extends Node

## Global run state (stage, coins, records) and scene navigation.

## true = development build (shows Debugger in the main menu).
## Set to false for release builds.
const IS_DEV_BUILD: bool = true

const SCENE_MAIN_MENU := "res://scenes/app/MainMenu.tscn"
const SCENE_GAME := "res://scenes/run/Game.tscn"
const SCENE_UNDER_CONSTRUCTION := "res://scenes/app/UnderConstruction.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/select/LevelSelect.tscn"
const SCENE_SOUND := "res://scenes/app/UnderConstruction.tscn"
const SCENE_GRAPHIC := "res://scenes/app/UnderConstruction.tscn"
const SCENE_CONTROLS := "res://scenes/app/ControlSettings.tscn"
const SCENE_DEBUGGER := "res://scenes/run/Game.tscn"

var current_world: int = 0
var current_phase: int = 0
var coins: int = 0
var records: Dictionary = {}
var is_running: bool = false
## True when Debugger opened the Phase 00 Dev Lab run.
var is_dev_lab_run: bool = false

## Title shown on the under-construction placeholder screen.
var pending_screen_title: String = ""


func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	EventBus.scene_changed.emit(path)


func open_under_construction(title: String) -> void:
	pending_screen_title = title
	change_scene(SCENE_UNDER_CONSTRUCTION)


func go_main_menu() -> void:
	is_dev_lab_run = false
	change_scene(SCENE_MAIN_MENU)


func go_control_settings() -> void:
	change_scene(SCENE_CONTROLS)


func go_level_select() -> void:
	is_dev_lab_run = false
	change_scene(SCENE_LEVEL_SELECT)


func go_dev_lab() -> void:
	if not IS_DEV_BUILD:
		return
	is_dev_lab_run = true
	change_scene(SCENE_GAME)


func start_run() -> void:
	is_running = true
	InputManager.sync_input_map(true)


func end_run() -> void:
	is_running = false
	is_dev_lab_run = false
	InputManager.sync_input_map(false)


func add_coins(amount: int) -> void:
	coins += amount
	EventBus.coin_collected.emit(amount)
	# TODO: AUDIO — coin collected
