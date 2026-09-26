extends SceneTree

const Shapes = preload("res://scripts/packages/package_shapes.gd")
const Grid = preload("res://scripts/warehouse/storage_grid.gd")
const Package = preload("res://scripts/packages/package.gd")
const MAIN = preload("res://scenes/main/Main.tscn")
const PACKAGE_SCENE = preload("res://scenes/packages/Package.tscn")
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
	await process_frame


func _key(game: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)


func _run() -> void:
	# Preserve a 1/60 s physics step while running the suite three times faster.
	Engine.time_scale = 3.0
	Engine.physics_ticks_per_second = 180
	Engine.max_fps = 360
	_check_shapes_and_grid()
	await _check_crane_safety()
	await _check_delivery()
	await _check_player_physics()
	await _check_placement()
	await _check_full_level()
	await _check_navigation()
	await _check_neon()
	print("Warehouse checks: ", "PASS" if _failures == 0 else "%d FAILURES" % _failures)
	quit(0 if _failures == 0 else 1)


func _check_shapes_and_grid() -> void:
	for kind in range(7):
		_check(Shapes.cells(kind) == Shapes.cells(kind, 4), "Four rotations must restore the piece")
		for turn in range(4):
			var unique := {}
			for cell in Shapes.cells(kind, turn):
				unique[cell] = true
				_check(cell.x >= 0 and cell.y >= 0, "Rotations must normalize coordinates")
			_check(unique.size() == 4, "Every rotation must contain four distinct boxes")
	var board := Grid.new()
	root.add_child(board)
	var square := Shapes.cells(1)
	_check(board.resting_row(square, 0, 192) == 4, "Squares must rest on the warehouse floor")
	var before: Array = board.grid.duplicate(true)
	_check(not board.place(square, 19, 4, 1) and board.grid == before, "Out-of-bounds placement must not change cells")
	_check(not board.place(square, 0, 2, 1), "Packages cannot float without support")
	for x in range(0, Grid.COLUMNS, 2):
		_check(board.place(square, x, 4, x + 1), "A strip of squares must fit the floor")
	_check(board.completed_rows() == 2, "Only completely filled rows count")
	_check(board.grid[5].count(0) == 0, "Completed rows must remain as solid platforms")
	_check(board.resting_row(square, 0, 128) == 2, "Next row must stack on the existing packages")
	_check(board.place(square, 0, 2, 100), "Stacking must accept a supported piece")
	_check(not board.can_remove(1) and not board.remove_package(1), "Do not remove the sole support of a stack")
	_check(board.remove_package(100) and board.remove_package(1), "Remove the top first, then its base")
	_check(board.completed_rows() == 0, "Taking out boxes must reopen both rows, not farm points")
	_check(board.resting_row(square, 0, -200) == -1, "Do not place boxes out of reach")
	# Two interlocked groups cannot support each other after losing their base.
	for row: Array in board.grid:
		row.fill(0)
	board.grid[5][0] = 1
	board.grid[4][0] = 2
	board.grid[3][0] = 3
	board.grid[3][1] = 2
	board.grid[4][1] = 3
	_check(not board.can_remove(1), "Support cycles must still connect to the floor")
	board.free()


func _new_game() -> Node2D:
	var game := MAIN.instantiate() as Node2D
	game._machine_busy = true
	root.add_child(game)
	return game


func _give_piece(game: Node, kind: int, serial: int, turns: int = 0) -> Package:
	var package := PACKAGE_SCENE.instantiate() as Package
	game.packages.add_child(package)
	package.setup(kind, serial, Vector2(136, 220))
	package.turns = turns
	package.pick_up(game.player.carry_point)
	game._carried = package
	game.player.carrying = true
	return package


func _check_crane_safety() -> void:
	var game := MAIN.instantiate() as Node2D
	root.add_child(game)
	game.player.position = Vector2(136, 432)
	await _frames(120)
	_check(game._spawned == 0, "The crane must not start a delivery over the worker")
	game.player.position = Vector2(232, 432)
	for _attempt in range(60):
		if game._machine_busy:
			break
		await _frames(1)
	_check(game._machine_busy, "The crane must resume when the worker leaves reception")
	game.player.position = Vector2(136, 432)
	await _frames(120)
	_check(game._spawned == 0, "The crane must also recheck safety just before releasing")
	game.player.position = Vector2(232, 432)
	await _frames(100)
	_check(game._spawned == 1, "The suspended load must release after the worker moves away")
	game.queue_free()
	await process_frame


func _check_delivery() -> void:
	var game := MAIN.instantiate() as Node2D
	root.add_child(game)
	for _attempt in range(180):
		if game._spawned == 1:
			break
		await _frames(1)
	_check(game._spawned == 1, "Ceiling crane must release a package")
	if game.packages.get_child_count() == 0:
		game.queue_free()
		await process_frame
		return
	var first: Package = game.packages.get_child(0)
	_check(first.state == Package.State.FALLING and not first.is_available(), "Airborne deliveries cannot be picked up")
	var released_y := first.position.y
	await _frames(10)
	_check(first.position.y > released_y, "Packages must fall with gravity")
	await _frames(65)
	_check(first.state == Package.State.READY, "Delivery must land on the physical floor")
	_check(absf(first.position.y + 64 - 432) < 1, "The landed package must not sink into the floor")
	await _frames(260)
	_check(game._spawned == 1, "An occupied delivery zone must pause the machine")
	game.player.position = Vector2(212, 432)
	game.player.facing = -1
	_key(game, KEY_F)
	_check(game._carried == first and first.collision_layer == 0, "F must pick up a nearby package and release its collisions")
	_check(game.player.is_physics_processing(), "Carrying must not freeze movement")
	_check(game.player.carrying, "Picking up must enable the raised-arm carrying pose")
	game.player.position = Vector2(232, 432)
	game.player.facing = 1
	_key(game, KEY_F)
	_check(first.state == Package.State.PLACED and game._carried == null, "F must place directly into the warehouse")
	_check(not game.player.carrying, "Placing must release the carrying pose")
	await _frames(260)
	_check(game._spawned == 2, "Clearing reception must resume deliveries")
	game.queue_free()
	await process_frame


func _check_player_physics() -> void:
	var game := _new_game()
	await _frames(8)
	_check(game.player.is_on_floor(), "The monkey must stand on the physical warehouse floor")
	var block := _give_piece(game, 1, 100)
	game.player.position = Vector2(232, 432)
	game.player.facing = 1
	game._place_carried()
	await _frames(3)
	Input.action_press("ui_right")
	await _frames(40)
	_check(game.player.position.x <= 242.2, "The monkey cannot walk through placed boxes")
	Input.action_press("ui_accept")
	await _frames(30)
	_check(game.player.position.y < 365, "Space must lift the monkey above a two-box stack")
	_check(game.player.position.x > 320, "The monkey must be able to jump across the stack")
	Input.action_release("ui_right")
	Input.action_release("ui_accept")
	await _frames(70)
	_check(game.player.is_on_floor() and absf(game.player.position.y - 432) < 1, "The monkey must fall back onto the floor")

	game.player.position = Vector2(226, 432)
	game.player.velocity = Vector2.ZERO
	await _frames(4)
	Input.action_press("ui_accept")
	Input.action_press("ui_right")
	await _frames(16)
	Input.action_release("ui_right")
	await _frames(40)
	Input.action_release("ui_accept")
	await _frames(30)
	_check(game.player.is_on_floor() and absf(game.player.position.y - 368) < 1, "Placed boxes must support the monkey as platforms")

	var carried := _give_piece(game, 2, 101)
	var start_x: float = game.player.position.x
	Input.action_press("ui_right")
	Input.action_press("ui_accept")
	await _frames(35)
	Input.action_release("ui_right")
	Input.action_release("ui_accept")
	_check(game.player.position.x > start_x + 70 and carried.state == Package.State.CARRIED, "The monkey must jump and move while carrying a package")
	_check(carried.position.distance_to(game.player.carry_point.global_position) < 90, "Carried artwork must follow the monkey")
	await _frames(65)
	_check(game.player.is_on_floor(), "Carrying cannot disable landing or gravity")
	_check(block.state == Package.State.PLACED and block.collision_layer == 2, "The obstacle must remain in the scene after jumping")
	game.queue_free()
	await process_frame
	await _check_tall_stack_jump()


func _check_tall_stack_jump() -> void:
	var game := _new_game()
	await _frames(8)
	var tower := _give_piece(game, 0, 100, 1)
	game.player.position = Vector2(232, 432)
	game.player.facing = 1
	game._place_carried()
	_check(tower.state == Package.State.PLACED, "A vertical I piece must fit on the floor")
	await _frames(4)
	Input.action_press("ui_right")
	Input.action_press("ui_accept")
	await _frames(37)
	Input.action_release("ui_right")
	Input.action_release("ui_accept")
	await _frames(70)
	_check(game.player.position.x > 303 and game.player.is_on_floor(), "A full jump must clear even a four-box vertical package")
	game.queue_free()
	await process_frame


func _check_placement() -> void:
	var game := _new_game()
	await _frames(4)
	var package := _give_piece(game, 2, 100)
	var original := package.cells()
	_key(game, KEY_E)
	_check(package.turns == 1 and package.cells() != original, "E must rotate the carried group")
	_key(game, KEY_Q)
	_check(package.turns == 0 and package.cells() == original, "Q must reverse the rotation")
	game.player.position = Vector2(924, 432)
	game.player.facing = 1
	_key(game, KEY_F)
	_check(game._carried == package and not game._preview_valid, "Invalid placement must preserve the carried package")
	_check(not game._space_clear(package.cells(), game.player.position + Vector2(-10, -50)), "Do not place boxes inside the monkey")
	game.player.position = Vector2(232, 432)
	game.player.facing = 1
	_key(game, KEY_F)
	_check(package.state == Package.State.PLACED and package._shapes.size() == 4, "Placed tetrominoes need four matching physical cells")
	game.player.position = Vector2(232, 432)
	_key(game, KEY_F)
	_check(game._carried == package and game.board.grid[5][0] == 0, "Placed packages can be picked up and reorganized")
	game.player.position = Vector2(224, 432)
	game.player.facing = -1
	_key(game, KEY_F)
	await _frames(8)
	_check(package.state == Package.State.READY and game._carried == null, "A carried package can be set aside in reception")
	_check(not game._reception_clear(), "Set-aside packages must stop new deliveries")
	game.queue_free()
	await process_frame


func _check_full_level() -> void:
	var game := _new_game()
	var columns := [0, 2, 4, 6, 8, 8, 10, 10, 12, 14, 16, 18, 0, 2, 4, 6, 12, 14, 16, 18]
	for index in range(columns.size()):
		var kind: int = game.INTRO_LOT[index]
		var turns := 2 if index in [5, 7] else 0
		var package := _give_piece(game, kind, index + 1, turns)
		var width := Shapes.bounds(package.cells()).x
		var neighbor: int = columns[index] + width
		var feet := 432.0
		if neighbor < Grid.COLUMNS:
			for row in range(Grid.ROWS):
				if game.board.grid[row][neighbor] != 0:
					feet = game.board.position.y + row * Grid.CELL_SIZE
					break
		game.player.position = Vector2(game.board.position.x + neighbor * Grid.CELL_SIZE + 24, feet)
		game.player.facing = -1
		game._place_carried()
		_check(package.state == Package.State.PLACED, "Opening lot placement %d must fit" % (index + 1))
		for cell_index in range(package.cells().size()):
			_check(package._shapes[cell_index].position == (Vector2(package.cells()[cell_index]) + Vector2.ONE * 0.5) * 32, "Collision cells must match the rotated package")
		_check(game.player.is_physics_processing() or index == columns.size() - 1, "Arrangement must keep live platformer controls")
	_check(game.rows_completed == 4, "The opening lot must be solvable as four complete rows")
	_check(game.mode == game.Mode.FINISHED and game.result_overlay.visible, "Four rows must show the victory screen")
	_check(game.packages.get_child_count() == 20, "Completed rows cannot delete the warehouse platforms")
	_check(game.spawn_timer.is_stopped() and not game.player.is_physics_processing(), "Victory must stop deliveries and movement")
	game.queue_free()
	await process_frame


func _check_navigation() -> void:
	change_scene_to_file("res://scenes/ui/StartMenu.tscn")
	await process_frame
	await process_frame
	current_scene.start_button.pressed.emit()
	await create_timer(0.6).timeout
	_check(current_scene.scene_file_path == "res://scenes/main/Main.tscn", "Start button must open the warehouse")
	var previous_id: int = current_scene.get_instance_id()
	_key(current_scene, KEY_R)
	await process_frame
	await process_frame
	_check(current_scene.get_instance_id() != previous_id and current_scene.rows_completed == 0, "R must restart with an empty warehouse")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	current_scene._unhandled_input(cancel)
	await process_frame
	await process_frame
	_check(current_scene.scene_file_path == "res://scenes/ui/StartMenu.tscn", "Esc must return to the menu")
	current_scene.queue_free()
	await process_frame


func _check_neon() -> void:
	var menu = preload("res://scenes/ui/StartMenu.tscn").instantiate()
	root.add_child(menu)
	var title: Label = menu.get_node("MenuPanel/Menu/Title")
	_check(title.get_child_count() == 5, "Title must retain five back-glow layers")
	var original_color := title.get_theme_color("font_color")
	await create_timer(0.3).timeout
	var initial_alpha: float = title.get_child(0).modulate.a
	await create_timer(0.6).timeout
	_check(title.get_child(0).modulate.a > initial_alpha, "White neon must pulse over time")
	_check(title.get_theme_color("font_color") == original_color, "Glow must preserve the blue title")
	menu.queue_free()
	await process_frame
