extends Node2D


func _ready() -> void:
	_add_solid(Rect2(16, 432, 928, 32))
	_add_solid(Rect2(-16, 80, 32, 384))
	_add_solid(Rect2(944, 80, 32, 384))


func _add_solid(box: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box.size
	collider.shape = shape
	body.position = box.get_center()
	body.add_child(collider)
	add_child(body)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("101e2c"))
	draw_rect(Rect2(16, 85, 928, 347), Color("1b3042"))
	for x in range(32, 944, 64):
		draw_line(Vector2(x, 85), Vector2(x, 430), Color("243b4e"), 1)
	for x in [32, 240, 912]:
		draw_rect(Rect2(x, 85, 8, 347), Color("2d4b62"))
		draw_line(Vector2(x, 85), Vector2(x, 432), Color("406987"), 1)
	# Loading bay and the storage lanes share the same physical floor.
	draw_rect(Rect2(64, 226, 144, 206), Color("152939"))
	for y in range(234, 430, 13):
		draw_line(Vector2(68, y), Vector2(204, y), Color("263d4f"), 2)
	draw_rect(Rect2(56, 414, 160, 18), Color("286499"))
	for x in range(58, 212, 16):
		draw_line(Vector2(x, 416), Vector2(x + 10, 429), Color("74b4e4"), 3)
	draw_rect(Rect2(16, 434, 928, 26), Color("2b4559"))
	draw_line(Vector2(16, 434), Vector2(944, 434), Color("589bcc"), 3)
	for x in range(24, 940, 48):
		draw_circle(Vector2(x, 447), 2, Color("162938"))
	# Three low-key warehouse lights, without competing with the action.
	for x in [336, 560, 784]:
		draw_line(Vector2(x, 85), Vector2(x, 146), Color("35546b"), 2)
		draw_rect(Rect2(x - 35, 146, 70, 7), Color("6f9ebf"))
		draw_line(Vector2(x - 28, 154), Vector2(x + 28, 154), Color("c3eaff"), 3)
