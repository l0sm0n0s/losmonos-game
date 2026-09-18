extends Node2D

const MENU_SCENE := "res://scenes/ui/StartMenu.tscn"
const PACKAGE_SCENE := preload("res://scenes/packages/Package.tscn")
const Shapes = preload("res://scripts/packages/package_shapes.gd")
const Package = preload("res://scripts/packages/package.gd")
const StorageGrid = preload("res://scripts/warehouse/storage_grid.gd")
const Crane = preload("res://scripts/warehouse/ceiling_crane.gd")
const ROW_GOAL := 4
const MAX_WAITING := 3
const INTERACTION_DISTANCE := 72.0
const STATION := Vector2(610, 385)
const DELIVERY_SPOTS := [Vector2(140, 310), Vector2(300, 310), Vector2(460, 310)]
const INTRO_LOT := [1, 1, 1, 0, 1, 0]
enum Mode { WALKING, PLACING, FINISHED }

var mode := Mode.WALKING
var rows_completed := 0
var _spawned := 0
var _carried: Package
var _machine_busy := false
var _turns := 0
var _column := 0
var _bag: Array = []
var _message_time := 0.0

@onready var player: CharacterBody2D = $Player
@onready var packages: Node2D = $Packages
@onready var board: StorageGrid = $Warehouse/StorageGrid
@onready var crane: Crane = $Warehouse/CeilingCrane
@onready var spawn_timer: Timer = $SpawnTimer
@onready var counter_label: Label = $HUD/TopBar/Counter
@onready var prompt_label: Label = $HUD/Prompt/Text
@onready var machine_status: Label = $HUD/MachineStatus
@onready var board_hint: Label = $HUD/BoardHint
@onready var result_overlay: Control = $HUD/ResultOverlay


func _ready() -> void:
	spawn_timer.timeout.connect(_feed_next_package)
	_update_counter()
	call_deferred("_feed_next_package")


func _process(delta: float) -> void:
	_message_time = maxf(0, _message_time - delta)
	if mode == Mode.FINISHED:
		return
	var waiting := _waiting_count()
	machine_status.text = "POLEA EN MARCHA" if _machine_busy else ("RECEPCIÓN LLENA · EN ESPERA" if waiting >= MAX_WAITING else "PREPARANDO SIGUIENTE CAJA")
	if _message_time <= 0:
		_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if mode == Mode.PLACING:
			_cancel_placement()
		else:
			get_tree().change_scene_to_file(MENU_SCENE)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	if mode == Mode.FINISHED:
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			get_tree().reload_current_scene()
		return
	if mode == Mode.PLACING:
		if event.is_action_pressed("ui_left", true):
			_column -= 1
		elif event.is_action_pressed("ui_right", true):
			_column += 1
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
			_turns = posmod(_turns + (-1 if event.keycode == KEY_Q else 1), 4)
		elif event.is_action_pressed("ui_accept") and not event.is_echo():
			_place_carried()
			return
		_update_preview()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		_interact()


func _feed_next_package() -> void:
	if mode == Mode.FINISHED or _machine_busy:
		return
	var slot := _free_delivery_slot()
	if _waiting_count() >= MAX_WAITING or slot < 0:
		spawn_timer.start(0.6)
		return
	var kind := _next_kind()
	_machine_busy = true
	var release_point: Vector2 = await crane.release_package(DELIVERY_SPOTS[slot].x, kind)
	if mode == Mode.FINISHED:
		return
	var package := PACKAGE_SCENE.instantiate() as Package
	packages.add_child(package)
	_spawned += 1
	package.setup(kind, _spawned, release_point, DELIVERY_SPOTS[slot], slot)
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
		if package != _carried and not package.is_queued_for_deletion():
			count += 1
	return count


func _free_delivery_slot() -> int:
	for slot in range(DELIVERY_SPOTS.size()):
		var occupied := false
		for package: Package in packages.get_children():
			if package == _carried or package.is_queued_for_deletion():
				continue
			if package.delivery_slot == slot or package.global_position.distance_to(DELIVERY_SPOTS[slot]) < 78:
				occupied = true
				break
		if not occupied:
			return slot
	return -1


func _interact() -> void:
	if is_instance_valid(_carried):
		if player.global_position.distance_to(STATION) <= 85:
			_begin_placement()
		else:
			_carried.drop(player.global_position + player.facing_direction * 46)
			_carried = null
		return
	var nearest := _nearest_package()
	if nearest != null:
		_carried = nearest
		_carried.pick_up(player.carry_point)


func _nearest_package() -> Package:
	var nearest: Package
	var distance_limit := INTERACTION_DISTANCE
	for package: Package in packages.get_children():
		if not package.is_available():
			continue
		var distance := player.global_position.distance_to(package.global_position)
		if distance < distance_limit:
			nearest = package
			distance_limit = distance
	return nearest


func _begin_placement() -> void:
	if not board.has_space_for(_carried.kind):
		_finish(false)
		return
	mode = Mode.PLACING
	player.set_controls_enabled(false)
	_turns = 0
	_column = 0
	_message_time = 0
	board_hint.text = "PIEZA %s · ENCAJA SIN DEJAR HUECOS" % Shapes.NAMES[_carried.kind]
	_update_preview()


func _update_preview() -> void:
	if not is_instance_valid(_carried):
		return
	var shape := Shapes.cells(_carried.kind, _turns)
	_column = clampi(_column, 0, StorageGrid.COLUMNS - Shapes.bounds(shape).x)
	board.show_preview(shape, _column)


func _cancel_placement() -> void:
	mode = Mode.WALKING
	board.clear_preview()
	player.set_controls_enabled(true)
	board_hint.text = "Completa filas para despachar cajas"
	_message_time = 0


func _place_carried() -> void:
	var cleared := board.place(Shapes.cells(_carried.kind, _turns), _column, _carried.kind)
	if cleared < 0:
		_show_message("No cabe aquí. Cambia de columna o gira con Q / E.")
		return
	_carried.queue_free()
	_carried = null
	rows_completed += cleared
	_cancel_placement()
	_update_counter()
	if rows_completed >= ROW_GOAL:
		_finish(true)
	elif cleared > 0:
		_show_message("¡%d fila(s) completas! Cajas despachadas." % cleared)


func _update_counter() -> void:
	counter_label.text = "FILAS  %d / %d" % [rows_completed, ROW_GOAL]


func _update_prompt() -> void:
	if mode == Mode.PLACING:
		prompt_label.text = "← → mover pieza   ·   Q / E girar   ·   Espacio colocar   ·   Esc volver"
	elif is_instance_valid(_carried):
		prompt_label.text = "ESPACIO · ORGANIZAR EN ESTANTERÍA" if player.global_position.distance_to(STATION) <= 85 else "Lleva las cajas al puesto azul de la derecha · Espacio para soltar"
	elif _nearest_package() != null:
		prompt_label.text = "ESPACIO · RECOGER CAJAS"
	elif _spawned == 0 or (_spawned == 1 and packages.get_child_count() > 0 and not packages.get_child(0).is_available()):
		prompt_label.text = "La polea deja caer cajas. Recógelas cuando toquen el suelo."
	else:
		prompt_label.text = "Recoge las cajas de recepción y completa 4 filas en la estantería"


func _show_message(message: String) -> void:
	prompt_label.text = message
	_message_time = 2.5


func _finish(won: bool) -> void:
	mode = Mode.FINISHED
	spawn_timer.stop()
	crane.stop()
	player.set_controls_enabled(false)
	for package: Package in packages.get_children():
		package.set_process(false)
	board.clear_preview()
	$HUD/Prompt.hide()
	result_overlay.show()
	$HUD/ResultOverlay/Card/Content/Stamp.text = "TURNO COMPLETADO" if won else "ESTANTERÍA LLENA"
	$HUD/ResultOverlay/Card/Content/Heading.text = "¡Buen trabajo!" if won else "¡A reorganizar!"
	$HUD/ResultOverlay/Card/Content/Message.text = "Completaste %d filas. El almacén está en orden." % rows_completed if won else "Esta pieza ya no cabe. Intenta dejar menos huecos."
	result_overlay.modulate.a = 0
	create_tween().tween_property(result_overlay, "modulate:a", 1.0, 0.3)
