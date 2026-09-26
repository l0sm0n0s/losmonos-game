extends Node2D

const Shapes = preload("res://scripts/packages/package_shapes.gd")

@export var showcase := false
@export var rail_width := 500.0
@export var box_size := 18.0

var trolley_x := 140.0
var rope_length := 24.0
var _kind := 0
var _loaded := false
var _wheel_angle := 0.0
var _motion: Tween


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


func release_package(target_x: float, kind: int, can_release: Callable = Callable()) -> Vector2:
	_kind = kind
	_loaded = true
	_motion = create_tween()
	_motion.tween_property(self, "trolley_x", target_x, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(self, "rope_length", 57.0, 0.45)
	_motion.tween_interval(0.2)
	await _motion.finished
	while can_release.is_valid() and not can_release.call():
		await get_tree().create_timer(0.1).timeout
		if not is_processing():
			return Vector2.ZERO
	_loaded = false
	var release_point := Vector2(trolley_x, 125 + rope_length + 24) + Vector2(0, Shapes.bounds(Shapes.cells(_kind)).y * box_size * 0.5)
	_motion = create_tween()
	_motion.tween_property(self, "rope_length", 24.0, 0.4)
	return to_global(release_point)


func stop() -> void:
	if is_instance_valid(_motion):
		_motion.kill()
	set_process(false)


func _draw() -> void:
	draw_rect(Rect2(63, 96, rail_width, 18), Color("172a39"))
	draw_line(Vector2(63, 94), Vector2(63 + rail_width, 94), Color("6aaee4"), 4)
	for x in range(70, int(60 + rail_width), 32):
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
