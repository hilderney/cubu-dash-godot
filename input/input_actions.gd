class_name InputActions
extends RefCounted

## Generic gameplay / UI actions shared by every input scheme.

const LEFT := "left"
const RIGHT := "right"
const UP := "up"
const DOWN := "down"
const BTN_A := "btn_a"
const BTN_B := "btn_b"
const BTN_START := "btn_start"

const ALL: Array[String] = [LEFT, RIGHT, UP, DOWN, BTN_A, BTN_B, BTN_START]

const VIRTUAL_LEFT := "virtual_left"
const VIRTUAL_RIGHT := "virtual_right"
const VIRTUAL_UP := "virtual_up"
const VIRTUAL_DOWN := "virtual_down"
const VIRTUAL_A := "virtual_a"
const VIRTUAL_B := "virtual_b"
const VIRTUAL_START := "virtual_start"

const ALL_VIRTUAL: Array[String] = [
	VIRTUAL_LEFT, VIRTUAL_RIGHT, VIRTUAL_UP, VIRTUAL_DOWN,
	VIRTUAL_A, VIRTUAL_B, VIRTUAL_START,
]


static func display_label(action: String) -> String:
	match action:
		LEFT:
			return "LEFT"
		RIGHT:
			return "RIGHT"
		UP:
			return "UP"
		DOWN:
			return "DOWN"
		BTN_A:
			return "A  JUMP / CONFIRM"
		BTN_B:
			return "B  DASH / CANCEL"
		BTN_START:
			return "START  PAUSE"
		_:
			return action.to_upper()


static func ui_mirror(action: String) -> String:
	match action:
		LEFT:
			return "ui_left"
		RIGHT:
			return "ui_right"
		UP:
			return "ui_up"
		DOWN:
			return "ui_down"
		BTN_A:
			return "ui_accept"
		BTN_B:
			return "ui_cancel"
		_:
			return ""


static func mirrored_actions(action: String) -> Array[String]:
	var names: Array[String] = [action]
	var mirrored := ui_mirror(action)
	if not mirrored.is_empty():
		names.append(mirrored)
	return names
