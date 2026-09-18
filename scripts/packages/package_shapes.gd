extends RefCounted

const NAMES := ["I", "O", "L", "J", "T", "S", "Z"]
const SHAPES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
]


static func cells(kind: int, turns: int = 0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in SHAPES[posmod(kind, SHAPES.size())]:
		var rotated := cell
		for _turn in range(posmod(turns, 4)):
			rotated = Vector2i(-rotated.y, rotated.x)
		result.append(rotated)
	var minimum := result[0]
	for cell in result:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
	for i in range(result.size()):
		result[i] -= minimum
	return result


static func bounds(shape: Array[Vector2i]) -> Vector2i:
	var result := Vector2i.ZERO
	for cell in shape:
		result.x = maxi(result.x, cell.x + 1)
		result.y = maxi(result.y, cell.y + 1)
	return result


static func draw_crate(canvas: CanvasItem, box: Rect2, ghost: bool = false) -> void:
	if ghost:
		canvas.draw_rect(box.grow(-2), Color(0.5, 0.85, 1, 0.18))
		canvas.draw_rect(box.grow(-2), Color(0.6, 0.9, 1, 0.85), false, 1.5)
		return
	canvas.draw_rect(box.grow(-1), Color("193750"))
	canvas.draw_rect(box.grow(-3), Color("b87e44"))
	canvas.draw_rect(Rect2(box.position + Vector2(3, 3), Vector2(box.size.x - 6, 3)), Color("dca364"))
	canvas.draw_rect(Rect2(box.position + Vector2(box.size.x * 0.42, 3), Vector2(box.size.x * 0.17, box.size.y - 6)), Color("85c2f5"))
