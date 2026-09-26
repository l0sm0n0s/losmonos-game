extends Node2D

const Shapes = preload("res://scripts/packages/package_shapes.gd")
const COLUMNS := 20
const ROWS := 6
const CELL_SIZE := 32.0

# Cells contain package IDs. Finished rows stay in the warehouse as platforms.
var grid: Array = []
var _preview: Array[Vector2i] = []
var _preview_cell := Vector2i.ZERO
var _preview_valid := false
var _completed: Array[int] = []
var _flash := 0.0


func _init() -> void:
	for _row in range(ROWS):
		var row: Array[int] = []
		row.resize(COLUMNS)
		row.fill(0)
		grid.append(row)


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0, _flash - delta)
		queue_redraw()


func fits(shape: Array[Vector2i], column: int, row: int) -> bool:
	for cell in shape:
		var x := column + cell.x
		var y := row + cell.y
		if x < 0 or x >= COLUMNS or y < 0 or y >= ROWS or grid[y][x] != 0:
			return false
	return true


func supported(shape: Array[Vector2i], column: int, row: int) -> bool:
	for cell in shape:
		var below := Vector2i(column, row) + cell + Vector2i.DOWN
		if below.y == ROWS:
			return true
		if below.x >= 0 and below.x < COLUMNS and below.y >= 0 and below.y < ROWS and grid[below.y][below.x] != 0:
			return true
	return false


func resting_row(shape: Array[Vector2i], column: int, feet_y: float) -> int:
	# Search from the floor up: the worker can also fill reachable side gaps.
	for row in range(ROWS - Shapes.bounds(shape).y, -1, -1):
		var bottom_y := global_position.y + (row + Shapes.bounds(shape).y) * CELL_SIZE
		if absf(bottom_y - feet_y) <= 104 and fits(shape, column, row) and supported(shape, column, row):
			return row
	return -1


func place(shape: Array[Vector2i], column: int, row: int, package_id: int) -> bool:
	if package_id <= 0 or not fits(shape, column, row) or not supported(shape, column, row):
		return false
	for cell in shape:
		grid[row + cell.y][column + cell.x] = package_id
	_refresh_completed()
	return true


func can_remove(package_id: int) -> bool:
	# Trace support back to the floor; mutually interlocked groups cannot float.
	var grounded := {}
	var supports := {}
	var remaining_ids := {}
	for y in range(ROWS):
		for x in range(COLUMNS):
			var id: int = grid[y][x]
			if id == 0 or id == package_id:
				continue
			remaining_ids[id] = true
			if y == ROWS - 1:
				grounded[id] = true
			else:
				var below: int = grid[y + 1][x]
				if below != 0 and below != id and below != package_id:
					if not supports.has(id):
						supports[id] = []
					supports[id].append(below)
	var changed := true
	while changed:
		changed = false
		for id: int in supports:
			if grounded.has(id):
				continue
			for below: int in supports[id]:
				if grounded.has(below):
					grounded[id] = true
					changed = true
					break
	for id: int in remaining_ids:
		if not grounded.has(id):
			return false
	return true


func remove_package(package_id: int) -> bool:
	if not can_remove(package_id):
		return false
	for row: Array in grid:
		for x in range(COLUMNS):
			if row[x] == package_id:
				row[x] = 0
	_refresh_completed()
	return true


func completed_rows() -> int:
	return _completed.size()


func _refresh_completed() -> void:
	var previous := _completed.size()
	_completed.clear()
	for y in range(ROWS):
		if not grid[y].has(0):
			_completed.append(y)
	if _completed.size() > previous:
		_flash = 1.0
	queue_redraw()


func show_preview(shape: Array[Vector2i], cell: Vector2i, valid: bool) -> void:
	_preview = shape
	_preview_cell = cell
	_preview_valid = valid
	queue_redraw()


func clear_preview() -> void:
	_preview = []
	queue_redraw()


func _draw() -> void:
	var size := Vector2(COLUMNS, ROWS) * CELL_SIZE
	for y in range(ROWS):
		var row_box := Rect2(Vector2(0, y * CELL_SIZE), Vector2(size.x, CELL_SIZE))
		if y in _completed:
			draw_rect(row_box, Color(0.32, 0.7, 1, 0.10 + _flash * 0.18))
			draw_line(row_box.position, row_box.position + Vector2(size.x, 0), Color("62baff"), 2)
		else:
			draw_line(row_box.position, row_box.position + Vector2(size.x, 0), Color(0.45, 0.7, 0.9, 0.12), 1)
	for x in range(COLUMNS + 1):
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, size.y), Color(0.45, 0.7, 0.9, 0.09), 1)
	draw_line(Vector2(0, size.y), size, Color("75c7ff"), 3)
	for x in [0.0, size.x]:
		draw_line(Vector2(x, size.y - 12), Vector2(x, size.y + 6), Color("b7e7ff"), 3)
	for y in range(ROWS):
		draw_circle(Vector2(size.x + 12, (y + 0.5) * CELL_SIZE), 3, Color("85d0ff") if y in _completed else Color("34536b"))
	for cell in _preview:
		var box := Rect2(Vector2(cell + _preview_cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		if _preview_valid:
			Shapes.draw_crate(self, box, true)
		else:
			draw_rect(box.grow(-2), Color(1, 0.35, 0.36, 0.16))
			draw_rect(box.grow(-2), Color(1, 0.45, 0.45, 0.8), false, 1.5)
