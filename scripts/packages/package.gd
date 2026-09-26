extends CharacterBody2D

const Shapes = preload("res://scripts/packages/package_shapes.gd")
const CELL_SIZE := 32.0
enum State { FALLING, READY, CARRIED, PLACED }

var kind := 0
var number := 1
var turns := 0
var state := State.FALLING
var grid_cell := Vector2i(-1, -1)
var highlighted := false
var _carrier: Marker2D
var _shapes: Array[CollisionShape2D] = []


func setup(shape_kind: int, serial: int, release_point: Vector2) -> void:
	kind = shape_kind
	number = serial
	position = release_point - Vector2(Shapes.bounds(cells())) * CELL_SIZE * 0.5
	_rebuild_collision()
	state = State.FALLING


func cells() -> Array[Vector2i]:
	return Shapes.cells(kind, turns)


func _physics_process(delta: float) -> void:
	if state == State.CARRIED:
		if is_instance_valid(_carrier):
			global_position = _carrier.global_position - Vector2(Shapes.bounds(cells())) * CELL_SIZE * scale * Vector2(0.5, 1.0)
	elif state != State.PLACED:
		velocity.y = minf(velocity.y + 1250.0 * delta, 850.0)
		move_and_slide()
		state = State.READY if is_on_floor() else State.FALLING
	queue_redraw()


func is_available() -> bool:
	return state in [State.READY, State.PLACED]


func pick_up(carrier: Marker2D) -> void:
	_carrier = carrier
	state = State.CARRIED
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	scale = Vector2.ONE * 0.62
	z_index = 10


func rotate_piece(direction: int) -> void:
	if state != State.CARRIED:
		return
	turns = posmod(turns + direction, 4)
	queue_redraw()


func place_at(world_position: Vector2, cell: Vector2i) -> void:
	_carrier = null
	state = State.PLACED
	scale = Vector2.ONE
	global_position = world_position
	grid_cell = cell
	velocity = Vector2.ZERO
	_rebuild_collision()
	collision_layer = 2
	collision_mask = 1 | 2
	z_index = 2
	queue_redraw()


func drop_at(world_position: Vector2) -> void:
	place_at(world_position, Vector2i(-1, -1))
	state = State.FALLING
	collision_mask = 7


func world_cells() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for cell in cells():
		result.append(Rect2(global_position + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE))
	return result


func distance_to(point: Vector2) -> float:
	var distance := INF
	for box in world_cells():
		var closest := point.clamp(box.position, box.end)
		distance = minf(distance, point.distance_to(closest))
	return distance


func _rebuild_collision() -> void:
	for collider in _shapes:
		remove_child(collider)
		collider.queue_free()
	_shapes.clear()
	for cell in cells():
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2.ONE * CELL_SIZE
		collider.shape = box
		collider.position = (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE
		add_child(collider)
		_shapes.append(collider)
	queue_redraw()


func _draw() -> void:
	for cell in cells():
		var box := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		Shapes.draw_crate(self, box)
		if highlighted and is_available():
			draw_rect(box.grow(-1), Color("b8e6ff"), false, 2)
