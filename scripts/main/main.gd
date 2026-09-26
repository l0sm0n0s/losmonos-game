extends Node2D

const MENU_SCENE := "res://scenes/ui/StartMenu.tscn"
const PACKAGE_SCENE := preload("res://scenes/packages/Package.tscn")
const Shapes = preload("res://scripts/packages/package_shapes.gd")
const Package = preload("res://scripts/packages/package.gd")
const StorageGrid = preload("res://scripts/warehouse/storage_grid.gd")
const Worker = preload("res://scripts/player/player.gd")
const Crane = preload("res://scripts/warehouse/ceiling_crane.gd")
const ROW_GOAL := 4
const MAX_WAITING := 2
const INTERACTION_DISTANCE := 52.0
const RECEPTION := Rect2(64, 174, 144, 258)
# A solvable opening lot: squares, paired L/J pieces, then more squares.
const INTRO_LOT := [1, 1, 1, 1, 2, 2, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
enum Mode { WALKING, FINISHED }

var mode := Mode.WALKING
var rows_completed := 0
var _spawned := 0
var _carried: Package
var _machine_busy := false
var _bag: Array = []
var _message_time := 0.0
var _preview_cell := Vector2i.ZERO
var _preview_valid := false
var _preview_in_storage := true

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
	_update_counter()
	call_deferred("_feed_next_package")


func _process(delta: float) -> void:
	_message_time = maxf(0, _message_time - delta)
	if mode == Mode.FINISHED:
		return
	_update_preview()
	var nearest := _nearest_package() if not is_instance_valid(_carried) else null
	for package: Package in packages.get_children():
		package.highlighted = package == nearest
	if not _reception_clear():
		machine_status.text = "DESPEJA LA ZONA DE DESCARGA"
	elif _waiting_count() >= MAX_WAITING:
		machine_status.text = "ACOMODA LOS PAQUETES · EN ESPERA"
	else:
		machine_status.text = "POLEA EN MARCHA" if _machine_busy else "PREPARANDO SIGUIENTE PAQUETE"
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
	if _waiting_count() >= MAX_WAITING or not _reception_clear():
		spawn_timer.start(0.6)
		return
	var kind := _next_kind()
	_machine_busy = true
	var release_point: Vector2 = await crane.release_package(136.0, kind, _reception_clear)
	if mode == Mode.FINISHED:
		return
	var package := PACKAGE_SCENE.instantiate() as Package
	packages.add_child(package)
	_spawned += 1
	package.setup(kind, _spawned, release_point)
	_machine_busy = false
	spawn_timer.start(2.8)


func _next_kind() -> int:
	if _spawned < INTRO_LOT.size():
		return INTRO_LOT[_spawned]
	if _bag.is_empty():
		_bag = range(Shapes.SHAPES.size())
		_bag.shuffle()
	return _bag.pop_back()


func _waiting_count() -> int:
	var count := 0
	for package: Package in packages.get_children():
		if package.state != Package.State.PLACED and not package.is_queued_for_deletion():
			count += 1
	return count


func _reception_clear() -> bool:
	if RECEPTION.intersects(player.body_rect()):
		return false
	for package: Package in packages.get_children():
		if package == _carried or package.is_queued_for_deletion():
			continue
		for box in package.world_cells():
			if RECEPTION.intersects(box):
				return false
	return true


func _interact() -> void:
	if is_instance_valid(_carried):
		_place_carried()
		return
	var nearest := _nearest_package()
	if nearest == null:
		return
	if nearest.state == Package.State.PLACED and not board.remove_package(nearest.number):
		_show_message("Ese paquete sostiene otros. Retira primero los de arriba.")
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
	_preview_in_storage = column >= 0
	var row := board.resting_row(shape, column, player.global_position.y) if _preview_in_storage else -1
	var fallback_row := floori((player.global_position.y + 1 - board.global_position.y) / StorageGrid.CELL_SIZE) - size.y
	_preview_cell = Vector2i(column, row if row >= 0 else fallback_row)
	var origin := board.to_global(Vector2(_preview_cell) * StorageGrid.CELL_SIZE)
	_preview_valid = row >= 0 if _preview_in_storage else (
		origin.x >= 32 and origin.x + size.x * StorageGrid.CELL_SIZE <= 224
		and origin.y >= 174 and origin.y + size.y * StorageGrid.CELL_SIZE <= 433)
	_preview_valid = _preview_valid and _space_clear(shape, origin)
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
	var previous_rows := rows_completed
	var origin := board.to_global(Vector2(_preview_cell) * StorageGrid.CELL_SIZE)
	if _preview_in_storage:
		if not board.place(_carried.cells(), _preview_cell.x, _preview_cell.y, _carried.number):
			return
		_carried.place_at(origin, _preview_cell)
	else:
		_carried.drop_at(origin)
	_carried = null
	player.carrying = false
	board.clear_preview()
	_update_counter()
	if rows_completed >= ROW_GOAL:
		_finish()
	elif rows_completed > previous_rows:
		_show_message("¡Fila completa! Las cajas se quedan: salta encima para seguir apilando.")


func _update_counter() -> void:
	rows_completed = board.completed_rows()
	counter_label.text = "FILAS  %d / %d" % [rows_completed, ROW_GOAL]


func _update_prompt() -> void:
	if is_instance_valid(_carried):
		prompt_label.text = "F · COLOCAR AQUÍ     Q / E · GIRAR     ESPACIO · SALTAR CON EL PAQUETE" if _preview_valid else "Busca una silueta azul: muévete, gira el paquete o salta para alcanzar otro nivel."
	elif _nearest_package() != null:
		prompt_label.text = "F · RECOGER PAQUETE     Puedes reorganizar las cajas que no sostengan otras."
	else:
		prompt_label.text = "Llena 4 filas sin huecos, de una marca azul a la otra. Las cajas son plataformas."


func _show_message(message: String) -> void:
	prompt_label.text = message
	_message_time = 3.0


func _finish() -> void:
	mode = Mode.FINISHED
	spawn_timer.stop()
	crane.stop()
	player.set_controls_enabled(false)
	for package: Package in packages.get_children():
		package.set_physics_process(false)
	board.clear_preview()
	$HUD/Prompt.hide()
	result_overlay.show()
	$HUD/ResultOverlay/Card/Content/Stamp.text = "TURNO COMPLETADO"
	$HUD/ResultOverlay/Card/Content/Heading.text = "¡Bodega en orden!"
	$HUD/ResultOverlay/Card/Content/Message.text = "Completaste %d filas sin huecos." % rows_completed
	result_overlay.modulate.a = 0
	create_tween().tween_property(result_overlay, "modulate:a", 1.0, 0.3)
