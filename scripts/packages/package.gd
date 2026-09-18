extends Node2D

const Shapes = preload("res://scripts/packages/package_shapes.gd")
enum State { FALLING, READY, CARRIED }

var kind := 0
var number := 1
var delivery_slot := -1
var state := State.FALLING
var _height := 0.0
var _fall_speed := 0.0
var _carrier: Marker2D
var _landing_tween: Tween
var _font: Font = preload("res://assets/fonts/poppins/Poppins-SemiBold.ttf")


func setup(shape_kind: int, serial: int, release_point: Vector2, target: Vector2, slot: int) -> void:
	kind = shape_kind
	number = serial
	delivery_slot = slot
	global_position = target
	_height = maxf(0, target.y - release_point.y)
	state = State.FALLING
	queue_redraw()


func _process(delta: float) -> void:
	if state == State.FALLING:
		_fall_speed += 590.0 * delta
		_height = maxf(0, _height - _fall_speed * delta)
		if is_zero_approx(_height):
			state = State.READY
			_landing_tween = create_tween()
			_landing_tween.tween_property(self, "scale", Vector2(1.12, 0.88), 0.07)
			_landing_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	elif state == State.CARRIED and is_instance_valid(_carrier):
		global_position = global_position.lerp(_carrier.global_position, minf(delta * 20.0, 1.0))
	queue_redraw()


func is_available() -> bool:
	return state == State.READY


func pick_up(carrier: Marker2D) -> void:
	if not is_available():
		return
	if is_instance_valid(_landing_tween):
		_landing_tween.kill()
	scale = Vector2.ONE
	_carrier = carrier
	state = State.CARRIED
	delivery_slot = -1
	z_index = 20


func drop(world_position: Vector2) -> void:
	_carrier = null
	state = State.READY
	global_position = world_position.clamp(Vector2(94, 280), Vector2(550, 395))
	z_index = 2


func _draw() -> void:
	var shape := Shapes.cells(kind)
	var size := Vector2(Shapes.bounds(shape)) * 18.0
	var shadow_alpha := 0.28 * (1.0 - minf(_height / 220.0, 0.65))
	draw_set_transform(Vector2(0, size.y * 0.5), 0, Vector2(1.5, 0.3))
	draw_circle(Vector2.ZERO, maxf(14, size.x * 0.38), Color(0, 0, 0, shadow_alpha))
	draw_set_transform(Vector2(0, -_height))
	for cell in shape:
		Shapes.draw_crate(self, Rect2(Vector2(cell) * 18.0 - size * 0.5, Vector2(18, 18)))
	if state == State.READY:
		draw_string(_font, Vector2(-15, size.y * 0.5 + 16), "%02d · %s" % [number, Shapes.NAMES[kind]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("cee9ff"))
	draw_set_transform(Vector2.ZERO)
