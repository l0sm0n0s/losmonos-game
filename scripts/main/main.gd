extends Node2D

const MENU_SCENE := "res://scenes/ui/StartMenu.tscn"
const PACKAGE_SCENE := preload("res://scenes/packages/Package.tscn")
const Shapes = preload("res://scripts/packages/package_shapes.gd")
const Package = preload("res://scripts/packages/package.gd")
const StorageGrid = preload("res://scripts/warehouse/storage_grid.gd")
const Worker = preload("res://scripts/player/player.gd")
const Crane = preload("res://scripts/warehouse/ceiling_crane.gd")
@export_range(3.0, 30.0, 0.5) var delivery_interval := 5.0
const INTERACTION_DISTANCE := 52.0
enum Mode { WALKING, FINISHED }

var mode := Mode.WALKING
var survival_time := 0.0
var _spawned := 0
var _carried: Package
var _machine_busy := false
var _bag: Array = []
var _message_time := 0.0
var _preview_cell := Vector2i.ZERO
var _preview_valid := false
var _delivery_kind := 0

@onready var player: Worker = $Player
@onready var packages: Node2D = $Packages
@onready var board: StorageGrid = $Warehouse/StorageGrid
@onready var crane: Crane = $Warehouse/CeilingCrane
@onready var spawn_timer: Timer = $SpawnTimer
@onready var counter_label: Label = $HUD/TopBar/Counter
@onready var prompt_label: Label = $HUD/Prompt/Text
@onready var machine_status: Label = $HUD/MachineStatus
@onready var result_overlay: Control = $HUD/ResultOverlay


func _ready() -> void:
	spawn_timer.timeout.connect(_feed_next_package)
	crane.delivery_finished.connect(_on_delivery_finished)
	crane.collided.connect(_finish)
	spawn_timer.start(delivery_interval)
	_update_counter()
	call_deferred("_feed_next_package")


func _process(delta: float) -> void:
	_message_time = maxf(0, _message_time - delta)
	if mode == Mode.FINISHED:
		return
	survival_time += delta
	_update_counter()
	_update_preview()
	var nearest := _nearest_package() if not is_instance_valid(_carried) else null
	for package: Package in packages.get_children():
		package.highlighted = package == nearest
	machine_status.text = "BRAZO DESCARGANDO" if _machine_busy else "SIGUIENTE ENTREGA EN %.1f s" % spawn_timer.time_left
	if _message_time <= 0:
		_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
		return
	if mode == Mode.FINISHED:
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_interact()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_Q, KEY_E] and is_instance_valid(_carried):
			_carried.rotate_piece(-1 if event.keycode == KEY_Q else 1)
			_update_preview()
			get_viewport().set_input_as_handled()


func _feed_next_package() -> void:
	if mode == Mode.FINISHED or _machine_busy:
		return
	_delivery_kind = _next_kind()
	_machine_busy = true
	crane.start_delivery(_delivery_target(_delivery_kind), _delivery_kind, _crane_space_clear)


func _delivery_target(kind: int) -> float:
	# Keep every shape and the trolley inside the warehouse walls.
	var half_width := maxf(32.0, Shapes.bounds(Shapes.cells(kind)).x * 16.0)
	return randf_range(16.0 + half_width, 944.0 - half_width)


func _on_delivery_finished(release_point: Vector2, delivered: bool) -> void:
	_machine_busy = false
	if mode == Mode.FINISHED or not delivered:
		return
	var package := PACKAGE_SCENE.instantiate() as Package
	packages.add_child(package)
	_spawned += 1
	package.setup(_delivery_kind, _spawned, release_point)
	_update_counter()


func _next_kind() -> int:
	if _bag.is_empty():
		_bag = range(Shapes.SHAPES.size())
		_bag.shuffle()
	return _bag.pop_back()


func _crane_space_clear(crane_boxes: Array[Rect2]) -> bool:
	for package: Package in packages.get_children():
		if package.is_queued_for_deletion():
			continue
		for occupied in package.world_cells():
			for box in crane_boxes:
				if box.intersects(occupied):
					return false
	return true


func _interact() -> void:
	if is_instance_valid(_carried):
		_place_carried()
		return
	var nearest := _nearest_package()
	if nearest == null:
		return
	_carried = nearest
	_carried.pick_up(player.carry_point)
	player.carrying = true
	_update_counter()
	_update_preview()


func _nearest_package() -> Package:
	var nearest: Package
	var best_score := INF
	var hands := player.global_position + Vector2(player.facing * 12, -28)
	for package: Package in packages.get_children():
		if not package.is_available() or package.is_queued_for_deletion():
			continue
		var distance := package.distance_to(hands)
		if distance > INTERACTION_DISTANCE:
			continue
		var center := package.global_position + Vector2(Shapes.bounds(package.cells())) * StorageGrid.CELL_SIZE * 0.5
		var score := distance
		if (center.x - player.global_position.x) * player.facing < 0:
			score += 25
		if package.state == Package.State.READY:
			score -= 12
		if score < best_score:
			nearest = package
			best_score = score
	return nearest


func _update_preview() -> void:
	if not is_instance_valid(_carried):
		board.clear_preview()
		_preview_valid = false
		return
	var shape := _carried.cells()
	var size := Shapes.bounds(shape)
	var column: int
	if player.facing > 0:
		column = ceili((player.global_position.x + 18 - board.global_position.x) / StorageGrid.CELL_SIZE)
	else:
		column = floori((player.global_position.x - 18 - board.global_position.x) / StorageGrid.CELL_SIZE) - size.x
	var row := floori((player.global_position.y + 1 - board.global_position.y) / StorageGrid.CELL_SIZE) - size.y
	_preview_cell = Vector2i(column, row)
	var origin := board.to_global(Vector2(_preview_cell) * StorageGrid.CELL_SIZE)
	_preview_valid = (origin.x >= 16 and origin.x + size.x * StorageGrid.CELL_SIZE <= 944
		and origin.y >= 132 and origin.y + size.y * StorageGrid.CELL_SIZE <= 433
		and _space_clear(shape, origin))
	board.show_preview(shape, _preview_cell, _preview_valid)


func _space_clear(shape: Array[Vector2i], origin: Vector2) -> bool:
	for cell in shape:
		var box := Rect2(origin + Vector2(cell) * StorageGrid.CELL_SIZE, Vector2.ONE * StorageGrid.CELL_SIZE).grow(-0.5)
		if box.intersects(player.body_rect()):
			return false
		for package: Package in packages.get_children():
			if package == _carried or package.is_queued_for_deletion():
				continue
			for occupied in package.world_cells():
				if box.intersects(occupied):
					return false
	return true


func _place_carried() -> void:
	_update_preview()
	if not _preview_valid:
		_show_message("Aquí no cabe. Acércate a un hueco, gira con Q/E o salta sobre la pila.")
		return
	var origin := board.to_global(Vector2(_preview_cell) * StorageGrid.CELL_SIZE)
	_carried.drop_at(origin)
	_carried = null
	player.carrying = false
	board.clear_preview()


func _update_counter() -> void:
	counter_label.text = "%03d s · %d piezas" % [int(survival_time), _spawned]


func _update_prompt() -> void:
	if is_instance_valid(_carried):
		prompt_label.text = "F · COLOCAR AQUÍ     Q / E · GIRAR     ESPACIO · SALTAR CON EL PAQUETE" if _preview_valid else "Busca una silueta azul: muévete, gira el paquete o salta para alcanzar otro nivel."
	elif _nearest_package() != null:
		prompt_label.text = "F · RECOGER PAQUETE     Mueve las piezas para despejar el recorrido del brazo."
	else:
		prompt_label.text = "Despeja el recorrido: si el brazo o su carga chocan con una pieza anterior, pierdes."


func _show_message(message: String) -> void:
	prompt_label.text = message
	_message_time = 3.0


func _finish() -> void:
	if mode == Mode.FINISHED:
		return
	mode = Mode.FINISHED
	spawn_timer.stop()
	crane.stop()
	player.set_controls_enabled(false)
	for package: Package in packages.get_children():
		package.set_physics_process(false)
	board.clear_preview()
	$HUD/Prompt.hide()
	result_overlay.show()
	$HUD/ResultOverlay/Card/Content/Stamp.text = "TURNO INTERRUMPIDO"
	$HUD/ResultOverlay/Card/Content/Heading.text = "¡El brazo ha chocado!"
	$HUD/ResultOverlay/Card/Content/Message.text = "Resististe %d segundos y recibiste %d piezas." % [int(survival_time), _spawned]
	result_overlay.modulate.a = 0
	create_tween().tween_property(result_overlay, "modulate:a", 1.0, 0.3)
