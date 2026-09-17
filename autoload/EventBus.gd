extends Node

signal player_dashed
signal player_dash_ended
signal player_jumped
## Reserved until death / fail flow exists.
signal player_died
## Reserved until coin pickups exist. Emitted by GameManager.add_coins.
signal coin_collected(amount: int)
signal scene_changed(path: String)
