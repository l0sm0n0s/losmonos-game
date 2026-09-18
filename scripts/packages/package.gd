extends Area2D

const BELT_SPEED := 92.0

var _belt_target := Vector2.ZERO
var _on_belt := false
var _carried := false
var _stored := false
var _carrier: Marker2D

@onready var number_label: Label = $Art/Number
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(number: int, belt_target: Vector2) -> void:
	_belt_target = belt_target
	_on_belt = true
	number_label.text = "%02d" % number


func _process(delta: float) -> void:
	if _carried and is_instance_valid(_carrier):
		global_position = global_position.lerp(_carrier.global_position, minf(delta * 18.0, 1.0))
		return

	if _on_belt:
		global_position = global_position.move_toward(_belt_target, BELT_SPEED * delta)
		if global_position.distance_to(_belt_target) < 1.0:
			global_position = _belt_target
			_on_belt = false


func is_available() -> bool:
	return not _stored and not _carried and not _on_belt


func pick_up(carrier: Marker2D) -> void:
	if not is_available():
		return
	_carrier = carrier
	_carried = true
	z_index = 20
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.86, 0.86), 0.12)


func drop(world_position: Vector2) -> void:
	_carried = false
	_carrier = null
	global_position = world_position
	z_index = 2
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func store(target: Vector2) -> void:
	_carried = false
	_stored = true
	_carrier = null
	remove_from_group("packages")
	collision_shape.set_deferred("disabled", true)
	z_index = 3
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 0.28)
	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.28)
