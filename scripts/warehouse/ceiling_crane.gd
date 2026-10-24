extends Node2D

signal collided
signal delivery_finished(release_point: Vector2, delivered: bool)

const Shapes = preload("res://scripts/packages/package_shapes.gd")
const TRAVEL_TIME := 1.4
const LOWER_TIME := 0.6
const HOLD_TIME := 0.2
const RETRACT_TIME := 0.5

enum Phase { IDLE, TRAVEL, LOWER, HOLD, RETRACT }

@export var showcase := false
@export var rail_width := 500.0
@export var box_size := 18.0

var trolley_x := 140.0
var rope_length := 24.0
var _kind := 0
var _loaded := false
var _wheel_angle := 0.0
var _phase := Phase.IDLE
var _elapsed := 0.0
var _start_x := 0.0
var _target_x := 0.0
var _space_clear: Callable


func _ready() -> void:
	if showcase:
		_kind = 2
		_loaded = true


func _process(delta: float) -> void:
	_wheel_angle += delta * 2.5
	if showcase:
		trolley_x = 310.0 + sin(_wheel_angle * 0.15) * 30.0
		rope_length = 35.0 + sin(_wheel_angle * 0.45) * 9.0
	queue_redraw()


func start_delivery(target_x: float, kind: int, space_clear: Callable) -> void:
	if _phase != Phase.IDLE or not is_physics_processing():
		return
	_kind = kind
	_loaded = true
	_start_x = trolley_x
	_target_x = target_x
	_space_clear = space_clear
	_phase = Phase.TRAVEL
	_elapsed = 0.0


func _physics_process(delta: float) -> void:
	if showcase:
		return
	var old_position := Vector2(trolley_x, rope_length)
	_elapsed += delta
	var duration := 1.0
	match _phase:
		Phase.TRAVEL:
			duration = TRAVEL_TIME
			trolley_x = lerpf(_start_x, _target_x, clampf(_elapsed / duration, 0, 1))
		Phase.LOWER:
			duration = LOWER_TIME
			rope_length = lerpf(24.0, 57.0, clampf(_elapsed / duration, 0, 1))
		Phase.HOLD:
			duration = HOLD_TIME
		Phase.RETRACT:
			duration = RETRACT_TIME
			rope_length = lerpf(57.0, 24.0, clampf(_elapsed / duration, 0, 1))
	# Sample the whole movement so even a slow frame cannot skip a box.
	var next_position := Vector2(trolley_x, rope_length)
	var steps := maxi(1, ceili(old_position.distance_to(next_position) / 4.0))
	for step in range(1, steps + 1):
		var sample := old_position.lerp(next_position, float(step) / steps)
		trolley_x = sample.x
		rope_length = sample.y
		if _space_clear.is_valid() and not _space_clear.call(collision_rects()):
			stop()
			collided.emit()
			return
	if _phase == Phase.IDLE or _elapsed < duration:
		return
	_elapsed = 0.0
	match _phase:
		Phase.TRAVEL:
			_phase = Phase.LOWER
		Phase.LOWER:
			_phase = Phase.HOLD
		Phase.HOLD:
			var size := Vector2(Shapes.bounds(Shapes.cells(_kind))) * box_size
			var release_point := to_global(Vector2(trolley_x, 125 + rope_length + 24 + size.y * 0.5))
			_loaded = false
			_phase = Phase.RETRACT
			delivery_finished.emit(release_point, true)
		Phase.RETRACT:
			_phase = Phase.IDLE


func collision_rects() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	boxes.append(Rect2(to_global(Vector2(trolley_x - 32, 104)), Vector2(64, 28)))
	boxes.append(Rect2(to_global(Vector2(trolley_x - 7, 125)), Vector2(14, rope_length)))
	boxes.append(Rect2(to_global(Vector2(trolley_x - 10, 125 + rope_length - 10)), Vector2(20, 32)))
	if _loaded:
		var shape := Shapes.cells(_kind)
		var origin := to_global(Vector2(trolley_x - Shapes.bounds(shape).x * box_size * 0.5, 125 + rope_length + 24))
		for cell in shape:
			boxes.append(Rect2(origin + Vector2(cell) * box_size, Vector2.ONE * box_size))
	return boxes


func stop() -> void:
	queue_redraw()
	_phase = Phase.IDLE
	set_process(false)
	set_physics_process(false)


func _draw() -> void:
	draw_rect(Rect2(16, 96, rail_width, 18), Color("172a39"))
	draw_line(Vector2(16, 94), Vector2(16 + rail_width, 94), Color("6aaee4"), 4)
	for x in range(22, int(16 + rail_width), 32):
		draw_line(Vector2(x, 97), Vector2(x + 12, 111), Color("305775"), 3)
	draw_rect(Rect2(trolley_x - 32, 104, 64, 28), Color("327fcb"))
	for dx in [-22, 22]:
		var center := Vector2(trolley_x + dx, 112)
		draw_circle(center, 10, Color("101f2b"))
		draw_arc(center, 7, 0, TAU, 20, Color("b5d8f0"), 2)
		draw_line(center, center + Vector2.from_angle(_wheel_angle) * 7, Color("78b7e5"), 2)
	var hook := Vector2(trolley_x, 125 + rope_length)
	draw_line(Vector2(trolley_x - 6, 125), hook + Vector2(-6, -7), Color("a2bac9"), 2)
	draw_line(Vector2(trolley_x + 6, 125), hook + Vector2(6, -7), Color("a2bac9"), 2)
	draw_circle(hook, 10, Color("327fcb"))
	draw_arc(hook + Vector2(0, 12), 7, -0.4, 3.7, 14, Color("d6e8f5"), 3)
	if _loaded:
		var shape := Shapes.cells(_kind)
		var origin := hook + Vector2(-Shapes.bounds(shape).x * box_size * 0.5, 24)
		for cell in shape:
			Shapes.draw_crate(self, Rect2(origin + Vector2(cell) * box_size, Vector2.ONE * box_size))
