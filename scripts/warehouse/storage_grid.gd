extends Node2D

const Shapes = preload("res://scripts/packages/package_shapes.gd")
const COLUMNS := 6
const ROWS := 8
const CELL_SIZE := 32.0

var grid: Array = []
var _preview: Array[Vector2i] = []
var _preview_column := 0
var _flash_rows: Array[int] = []
var _flash := 0.0


func _init() -> void:
	for _row in range(ROWS):
		var row: Array[int] = []
		row.resize(COLUMNS)
		row.fill(0)
		grid.append(row)


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0, _flash - delta * 1.8)
		queue_redraw()


func fits(shape: Array[Vector2i], column: int, row: int) -> bool:
	for cell in shape:
		var x := column + cell.x
		var y := row + cell.y
		if x < 0 or x >= COLUMNS or y < 0 or y >= ROWS:
			return false
		if grid[y][x] != 0:
			return false
	return true


func landing_row(shape: Array[Vector2i], column: int) -> int:
	if not fits(shape, column, 0):
		return -1
	var row := 0
	while fits(shape, column, row + 1):
		row += 1
	return row


func has_space_for(kind: int) -> bool:
	for turns in range(4):
		for column in range(COLUMNS):
			if landing_row(Shapes.cells(kind, turns), column) >= 0:
				return true
	return false


func place(shape: Array[Vector2i], column: int, kind: int) -> int:
	var row := landing_row(shape, column)
	if row < 0:
		return -1
	for cell in shape:
		grid[row + cell.y][column + cell.x] = kind + 1
	var remaining: Array = []
	_flash_rows.clear()
	for y in range(ROWS):
		if not grid[y].has(0):
			_flash_rows.append(y)
		else:
			remaining.append(grid[y].duplicate())
	var cleared := _flash_rows.size()
	for _row in range(cleared):
		var empty_row: Array[int] = []
		empty_row.resize(COLUMNS)
		empty_row.fill(0)
		remaining.push_front(empty_row)
	grid = remaining
	_flash = 1.0 if cleared > 0 else 0.0
	clear_preview()
	return cleared


func show_preview(shape: Array[Vector2i], column: int) -> void:
	_preview = shape
	_preview_column = column
	queue_redraw()


func clear_preview() -> void:
	_preview.clear()
	queue_redraw()


func _draw() -> void:
	var size := Vector2(COLUMNS, ROWS) * CELL_SIZE
	draw_rect(Rect2(Vector2(-10, -10), size + Vector2(20, 20)), Color("102436"))
	for y in range(ROWS):
		for x in range(COLUMNS):
			var box := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			draw_rect(box.grow(-1), Color("213d50") if y % 2 == 0 else Color("1c3547"))
			if grid[y][x] > 0:
				Shapes.draw_crate(self, box)
	if not _preview.is_empty():
		var row := landing_row(_preview, _preview_column)
		for cell in _preview:
			var box := Rect2(Vector2(cell + Vector2i(_preview_column, maxi(row, 0))) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			if row >= 0:
				Shapes.draw_crate(self, box, true)
			else:
				draw_rect(box.grow(-2), Color(1, 0.35, 0.3, 0.65))
	for row in _flash_rows:
		draw_rect(Rect2(Vector2(0, row * CELL_SIZE), Vector2(size.x, CELL_SIZE)), Color(0.8, 0.95, 1, _flash * 0.75))
	draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color("70bfff"), false, 2)
