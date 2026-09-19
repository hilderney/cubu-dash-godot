extends RefCounted
class_name DevLabCatalog

## Builds Phase 00 catalog stub zones into the run World node.

const LAB_WIDTH := 10000.0
const KILL_ZONE_SCRIPT := preload("res://scenes/run/kill_zone.gd")


static func build(world: Node2D) -> void:
	_rebuild_ground_with_pits(world)
	_add_kill_zone(world)
	var zones := [
		{"x": 600.0, "title": "A JUMP", "color": Color("4ECDC4")},
		{"x": 1800.0, "title": "B DOUBLE", "color": Color("FFE66D")},
		{"x": 3000.0, "title": "C DASH", "color": Color("FF6B35")},
		{"x": 4200.0, "title": "D BREAK", "color": Color("F15BB5")},
		{"x": 5400.0, "title": "E WALL", "color": Color("E71D36")},
		{"x": 6600.0, "title": "F COIN", "color": Color("FEE440")},
		{"x": 7800.0, "title": "G FAIL", "color": Color("9B5DE5")},
		{"x": 9000.0, "title": "H CLEAR", "color": Color("00F5D4")},
	]
	for zone in zones:
		_add_zone_marker(world, zone.x, zone.title, zone.color)


## Continuous ground with pits so the player can fall into the kill zone.
static func _rebuild_ground_with_pits(world: Node2D) -> void:
	var old := world.get_node_or_null("Ground_StaticBody2D")
	if old != null:
		old.queue_free()

	# [start, end) segments — gaps at JUMP / DOUBLE / FAIL for testing falls.
	var segments: Array = [
		Vector2(0.0, 520.0),
		Vector2(900.0, 1650.0),
		Vector2(2300.0, 7700.0),
		Vector2(8300.0, LAB_WIDTH),
	]
	var index := 0
	for segment in segments:
		_add_ground_segment(world, segment.x, segment.y, index)
		index += 1


static func _add_ground_segment(world: Node2D, start_x: float, end_x: float, index: int) -> void:
	var width := end_x - start_x
	if width <= 1.0:
		return
	var ground := StaticBody2D.new()
	ground.name = "Ground_%d" % index
	world.add_child(ground)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 73.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(start_x + width * 0.5, 694.0)
	ground.add_child(collision)

	var visual := ColorRect.new()
	visual.offset_left = start_x
	visual.offset_top = 653.0
	visual.offset_right = end_x
	visual.offset_bottom = 729.0
	visual.color = Color(0, 0.7176471, 0.24705882, 1)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.add_child(visual)


static func _add_kill_zone(world: Node2D) -> void:
	var zone := Area2D.new()
	zone.name = "KillZone"
	zone.set_script(KILL_ZONE_SCRIPT)
	world.add_child(zone)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(LAB_WIDTH + 400.0, 200.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	# Below the basic floor (floor top ~653–729).
	collision.position = Vector2(LAB_WIDTH * 0.5, 880.0)
	zone.add_child(collision)

	var visual := ColorRect.new()
	visual.offset_left = -200.0
	visual.offset_top = 780.0
	visual.offset_right = LAB_WIDTH + 200.0
	visual.offset_bottom = 980.0
	visual.color = Color(0.9, 0.1, 0.2, 0.35)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(visual)


static func _add_zone_marker(world: Node2D, x: float, title: String, color: Color) -> void:
	var pad := ColorRect.new()
	pad.name = "Zone_%s" % title.replace(" ", "_")
	pad.position = Vector2(x, 560.0)
	pad.size = Vector2(220.0, 90.0)
	pad.color = Color(color.r, color.g, color.b, 0.55)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(pad)

	var label := Label.new()
	label.text = title
	label.position = Vector2(8.0, 28.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.03, 0.12, 0.2, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(label)
