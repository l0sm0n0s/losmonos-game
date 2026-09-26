extends Node2D

const FUR := Color("6b3f24")
const DARK_FUR := Color("402719")
const FACE := Color("d89c62")
const FACE_LIGHT := Color("efbd7e")
const UNIFORM_DARK := Color("263c4a")

@export var uniform_color := Color(0.22, 0.56, 0.95, 1)
@export var reflective_color := Color(0.7, 0.88, 1, 1)

var _moving := false
var _elapsed := 0.0
var _facing := 1.0
var _base_y := 0.0
var _carrying := false
var _airborne := false


func _ready() -> void:
	_base_y = position.y
	queue_redraw()


func set_movement(direction: Vector2) -> void:
	_moving = not direction.is_zero_approx()
	if absf(direction.x) > 0.05:
		_facing = signf(direction.x)


func _process(delta: float) -> void:
	_elapsed += delta
	var walking := _moving and not _airborne
	var target_bob := _base_y + (sin(_elapsed * 11.0) * 1.8 if walking else 0.0)
	position.y = lerpf(position.y, target_bob, minf(delta * 14.0, 1.0))
	rotation = lerpf(rotation, sin(_elapsed * 11.0) * 0.045 if walking else 0.0, minf(delta * 12.0, 1.0))
	queue_redraw()


func set_pose(carrying: bool, airborne: bool) -> void:
	_carrying = carrying
	_airborne = airborne


func _draw() -> void:
	# Silueta humanoide: cola, brazos y piernas.
	draw_arc(Vector2(-12.0 * _facing, 12.0), 21.0, 1.3, 4.7, 24, DARK_FUR, 7.0, true)
	if _carrying:
		for side in [-1, 1]:
			draw_polyline(PackedVector2Array([Vector2(side * 12, 9), Vector2(side * 28, -12), Vector2(side * 19, -34)]), FUR, 7, true)
			draw_circle(Vector2(side * 19, -34), 4, FACE)
	else:
		draw_line(Vector2(-12, 9), Vector2(-22, 24), FUR, 7, true)
		draw_line(Vector2(12, 9), Vector2(22, 24), FUR, 7, true)
	var foot_y := 31.0 if _airborne else 38.0
	draw_line(Vector2(-7, 25), Vector2(-10, foot_y), UNIFORM_DARK, 9, true)
	draw_line(Vector2(7, 25), Vector2(10, foot_y), UNIFORM_DARK, 9, true)
	draw_line(Vector2(-13, foot_y), Vector2(-7, foot_y), DARK_FUR, 5, true)
	draw_line(Vector2(7, foot_y), Vector2(13, foot_y), DARK_FUR, 5, true)

	# Torso con uniforme y chaleco de seguridad.
	draw_circle(Vector2(0.0, 13.0), 18.0, FUR)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 4), Vector2(14, 4), Vector2(16, 27), Vector2(-16, 27)]), UNIFORM_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 5), Vector2(-3, 4), Vector2(-1, 27), Vector2(-15, 26)]), uniform_color)
	draw_colored_polygon(PackedVector2Array([Vector2(3, 4), Vector2(14, 5), Vector2(15, 26), Vector2(1, 27)]), uniform_color)
	draw_line(Vector2(-14, 18), Vector2(14, 18), reflective_color, 2.5, true)

	# Cabeza y orejas.
	draw_circle(Vector2(-17.0, -8.0), 9.0, DARK_FUR)
	draw_circle(Vector2(17.0, -8.0), 9.0, DARK_FUR)
	draw_circle(Vector2(-17.0, -8.0), 5.5, FACE)
	draw_circle(Vector2(17.0, -8.0), 5.5, FACE)
	draw_circle(Vector2.ZERO, 20.0, FUR)

	# Gorra corporativa.
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -17), Vector2(-8, -25), Vector2(9, -25), Vector2(17, -17)]), UNIFORM_DARK)
	draw_line(Vector2(-17, -17), Vector2(20, -17), uniform_color, 5.0, true)

	# Rostro expresivo.
	draw_circle(Vector2(-7.0, -3.0), 9.5, FACE)
	draw_circle(Vector2(7.0, -3.0), 9.5, FACE)
	draw_circle(Vector2(0.0, 6.0), 11.0, FACE_LIGHT)
	draw_circle(Vector2(-6.0, -5.0), 2.4, Color.WHITE)
	draw_circle(Vector2(6.0, -5.0), 2.4, Color.WHITE)
	draw_circle(Vector2((-5.4 + 1.4 * _facing), -4.7), 1.2, DARK_FUR)
	draw_circle(Vector2((5.4 + 1.4 * _facing), -4.7), 1.2, DARK_FUR)
	draw_circle(Vector2(-3.0, 4.0), 1.2, DARK_FUR)
	draw_circle(Vector2(3.0, 4.0), 1.2, DARK_FUR)
	draw_arc(Vector2(0.0, 5.5), 5.5, 0.3, 2.8, 12, DARK_FUR, 1.8, true)
