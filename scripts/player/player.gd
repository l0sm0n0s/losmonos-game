extends CharacterBody2D

@export var speed: float = 250.0
@export var acceleration: float = 1400.0

@onready var monkey_art: Node2D = $MonkeyArt
@onready var carry_point: Marker2D = $CarryPoint

var facing_direction := Vector2.DOWN


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	move_and_slide()
	monkey_art.set_movement(direction)

	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
		carry_point.position = facing_direction * 38.0 + Vector2(0.0, -4.0)


func _draw() -> void:
	draw_set_transform(Vector2(0.0, 20.0), 0.0, Vector2(1.45, 0.5))
	draw_circle(Vector2.ZERO, 15.0, Color(0.16, 0.19, 0.12, 0.24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
