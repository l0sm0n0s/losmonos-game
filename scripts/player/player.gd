extends CharacterBody2D

@export var speed := 235.0
@export var acceleration := 1700.0
@export var gravity := 1650.0
@export var jump_speed := 720.0

@onready var monkey_art: Node2D = $MonkeyArt
@onready var carry_point: Marker2D = $CarryPoint

var facing := 1
var carrying := false
var _coyote_time := 0.0
var _jump_buffer := 0.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	direction = clampf(direction, -1, 1)
	velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	if not is_zero_approx(direction):
		facing = 1 if direction > 0 else -1
		carry_point.position.x = facing * 5.0

	_coyote_time = 0.1 if is_on_floor() else maxf(0, _coyote_time - delta)
	_jump_buffer = maxf(0, _jump_buffer - delta)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		_jump_buffer = 0.14
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	if _jump_buffer > 0 and _coyote_time > 0:
		velocity.y = -jump_speed
		_jump_buffer = 0
		_coyote_time = 0
	if Input.is_action_just_released("ui_accept") and velocity.y < -280:
		velocity.y = -280
	move_and_slide()
	monkey_art.set_movement(Vector2(direction, 0))
	monkey_art.set_pose(carrying, not is_on_floor())


func body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-14, -58), Vector2(28, 58))


func set_controls_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	velocity = Vector2.ZERO
	monkey_art.set_movement(Vector2.ZERO)
	monkey_art.set_pose(carrying, false)


func _draw() -> void:
	draw_set_transform(Vector2(0, 0), 0, Vector2(1.3, 0.24))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.24))
	draw_set_transform(Vector2.ZERO)
