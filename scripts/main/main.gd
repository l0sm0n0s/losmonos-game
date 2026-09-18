extends Node2D

const MENU_SCENE := "res://scenes/ui/StartMenu.tscn"
const PACKAGE_SCENE := preload("res://scenes/packages/Package.tscn")
const TOTAL_PACKAGES := 5
const INTERACTION_DISTANCE := 66.0

var _spawned := 0
var _stored := 0
var _carried_package: Area2D
var _game_finished := false

@onready var player: CharacterBody2D = $Player
@onready var packages: Node2D = $Packages
@onready var spawn_point: Marker2D = $Warehouse/Machine/SpawnPoint
@onready var storage_zone: Area2D = $Warehouse/StorageZone
@onready var spawn_timer: Timer = $SpawnTimer
@onready var counter_label: Label = $HUD/TopBar/Counter
@onready var prompt_panel: PanelContainer = $HUD/Prompt
@onready var prompt_label: Label = $HUD/Prompt/Text
@onready var machine_status: Label = $HUD/MachineStatus
@onready var victory_overlay: Control = $HUD/VictoryOverlay


func _ready() -> void:
	spawn_timer.timeout.connect(_spawn_package)
	_update_counter()
	_spawn_package()


func _process(_delta: float) -> void:
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)
		return

	if _game_finished and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
		return

	if not _game_finished and event.is_action_pressed("ui_accept"):
		_interact()


func _spawn_package() -> void:
	if _spawned >= TOTAL_PACKAGES:
		spawn_timer.stop()
		return

	var package := PACKAGE_SCENE.instantiate() as Area2D
	packages.add_child(package)
	package.global_position = spawn_point.global_position
	var belt_target := Vector2(570.0 - _spawned * 58.0, 170.0)
	package.call("setup", _spawned + 1, belt_target)
	_spawned += 1
	machine_status.text = "MÁQUINA: PRODUCIENDO  %d/%d" % [_spawned, TOTAL_PACKAGES]

	if _spawned >= TOTAL_PACKAGES:
		spawn_timer.stop()
		machine_status.text = "MÁQUINA: LOTE COMPLETO"


func _interact() -> void:
	if is_instance_valid(_carried_package):
		if storage_zone.overlaps_body(player):
			_store_carried_package()
		else:
			_carried_package.call("drop", player.global_position + player.facing_direction * 46.0)
			_carried_package = null
		return

	var nearest := _nearest_available_package()
	if nearest != null:
		_carried_package = nearest
		_carried_package.call("pick_up", player.carry_point)


func _nearest_available_package() -> Area2D:
	var nearest: Area2D
	var nearest_distance := INTERACTION_DISTANCE
	for node in get_tree().get_nodes_in_group("packages"):
		if not node.call("is_available"):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance < nearest_distance:
			nearest = node
			nearest_distance = distance
	return nearest


func _store_carried_package() -> void:
	var column := _stored % 2
	var row := floori(float(_stored) / 2.0)
	var target := storage_zone.global_position + Vector2(-33.0 + column * 66.0, -42.0 + row * 43.0)
	_carried_package.call("store", target)
	_carried_package = null
	_stored += 1
	_update_counter()
	_punch_counter()

	if _stored >= TOTAL_PACKAGES:
		_finish_level()


func _update_counter() -> void:
	counter_label.text = "PAQUETES  %d / %d" % [_stored, TOTAL_PACKAGES]


func _update_prompt() -> void:
	if _game_finished:
		prompt_panel.visible = false
		return

	if is_instance_valid(_carried_package):
		prompt_panel.visible = true
		if storage_zone.overlaps_body(player):
			prompt_label.text = "ESPACIO  ·  ACOMODAR PAQUETE"
		else:
			prompt_label.text = "Lleva el paquete a DESPACHO  ·  ESPACIO para soltar"
		return

	var nearest := _nearest_available_package()
	prompt_panel.visible = nearest != null
	if nearest != null:
		prompt_label.text = "ESPACIO  ·  RECOGER PAQUETE"


func _punch_counter() -> void:
	counter_label.pivot_offset = counter_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(counter_label, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(counter_label, "scale", Vector2.ONE, 0.12)


func _finish_level() -> void:
	_game_finished = true
	player.set_physics_process(false)
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	var card: Control = victory_overlay.get_node("Card")
	card.scale = Vector2(0.84, 0.84)
	card.pivot_offset = card.size * 0.5

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(card, "scale", Vector2.ONE, 0.38)
