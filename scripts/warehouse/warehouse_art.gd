extends Node2D


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("101e2c"))
	draw_rect(Rect2(32, 85, 618, 155), Color("203649"))
	for x in range(48, 650, 50):
		draw_line(Vector2(x, 85), Vector2(x, 240), Color("2a4256"), 1)
	draw_line(Vector2(32, 85), Vector2(650, 85), Color("398ed9"), 5)
	draw_rect(Rect2(32, 242, 618, 201), Color("354654"))
	for y in range(248, 445, 48):
		draw_line(Vector2(32, y), Vector2(650, y), Color("415260"), 1)
	for x in range(32, 651, 78):
		draw_line(Vector2(x, 242), Vector2(x, 443), Color("415260"), 1)
	for x in [140, 300, 460]:
		var pad := Rect2(x - 52, 266, 104, 90)
		draw_rect(pad, Color(0.24, 0.54, 0.8, 0.14))
		draw_rect(pad, Color("6ba6cf"), false, 1)
		for corner in [pad.position, pad.position + Vector2(84, 0), pad.position + Vector2(0, 90), pad.end - Vector2(20, 0)]:
			draw_line(corner, corner + Vector2(20, 0), Color("9ed7ff"), 3)
	draw_rect(Rect2(575, 346, 78, 91), Color(0.23, 0.6, 1, 0.3))
	draw_rect(Rect2(575, 346, 78, 91), Color("8acaff"), false, 2)
	draw_line(Vector2(589, 336), Vector2(628, 336), Color("8acaff"), 3)
	draw_line(Vector2(628, 336), Vector2(618, 327), Color("8acaff"), 3)
	draw_rect(Rect2(680, 120, 232, 308), Color("193144"))
	draw_line(Vector2(685, 120), Vector2(685, 443), Color("398ed9"), 8)
	draw_line(Vector2(908, 120), Vector2(908, 443), Color("398ed9"), 8)
	draw_rect(Rect2(680, 422, 232, 10), Color("265b87"))
