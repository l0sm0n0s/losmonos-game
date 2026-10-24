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
	game.spawn_timer.stop()
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
	for phase in ["travel", "lower", "retract", "idle"]:
		var game := _new_game()
		await _frames(2)
		game.crane.trolley_x = 160
		game.crane.start_delivery(800, 1, game._crane_space_clear)
		if phase == "lower":
			await _frames(86)
		elif phase == "retract" or phase == "idle":
			await _frames(135 if phase == "retract" else 168)
		var obstacle := PACKAGE_SCENE.instantiate() as Package
		game.packages.add_child(obstacle)
		obstacle.setup(1, 99, Vector2.ZERO)
		# Travel tests sweep over a box in a single deliberately slow tick.
		var location := Vector2(470, 145) if phase == "travel" else Vector2(792, 125 + game.crane.rope_length)
		obstacle.place_at(location, Vector2i(-1, -1))
		game.crane._physics_process(1.0 if phase == "travel" else 0.02)
		_check(game.mode == game.Mode.FINISHED, "Crane contact must lose during " + phase)
		_check(game.result_overlay.visible, "Collision must show the loss overlay")
		_check(game.spawn_timer.is_stopped() and not game.player.is_physics_processing(), "Loss must stop the timer and player")
		_check(not game.crane.is_physics_processing(), "Loss must freeze the crane")
		var count: int = game._spawned
		game._feed_next_package()
		await _frames(180)
		_check(game._spawned == count, "No late delivery may appear after a collision")
		game.queue_free()
		await process_frame


func _check_delivery() -> void:
	seed(12345)
	var game := MAIN.instantiate() as Node2D
	root.add_child(game)
	var destinations := {}
	for kind in range(7):
		for _sample in range(40):
			var x: float = game._delivery_target(kind)
			var half_width := Shapes.bounds(Shapes.cells(kind)).x * 16.0
			_check(x - half_width >= 16 and x + half_width <= 944, "All deliveries must fit within the map")
			destinations[int(x / 200)] = true
	_check(destinations.size() == 5, "Random destinations must cover the whole warehouse")
	for _attempt in range(180):
		if game._spawned == 1:
			break
		await _frames(1)
	_check(game._spawned == 1, "The crane must release its first package")
	if game.packages.get_child_count() == 0:
		game.queue_free()
		await process_frame
		return
	var first: Package = game.packages.get_child(0)
	_check(first.state == Package.State.FALLING, "New deliveries must fall under gravity")
	var previous_release: float = game.survival_time
	var released_y := first.position.y
	await _frames(10)
	_check(first.position.y > released_y, "A released package must move down")
	await _frames(70)
	_check(first.state == Package.State.READY, "A delivery must settle on the floor")
	_check(game.mode == game.Mode.WALKING, "The crane must not collide with its own newly released load")
	# Preserve old deliveries along the floor; the former two-piece cap must not apply.
	for expected in range(2, 5):
		first.position = Vector2(40, 368)
		for _attempt in range(330):
			if game._spawned >= expected or game.mode == game.Mode.FINISHED:
				break
			await _frames(1)
		_check(game._spawned == expected, "Periodic deliveries must continue past two waiting packages")
		_check(absf(game.survival_time - previous_release - game.delivery_interval) < 0.15, "Releases must stay five seconds apart")
		previous_release = game.survival_time
		if game._spawned >= expected:
			first = game.packages.get_child(expected - 1)
	_check(game.survival_time > 15, "The survival clock must keep advancing")
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
	_check(block.state == Package.State.READY and block.collision_layer == 2, "The obstacle must remain in the scene after jumping")
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
	_check(tower.state == Package.State.FALLING, "A vertical I piece must fit on the floor")
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
	_check(package.state == Package.State.FALLING and package._shapes.size() == 4, "Placed tetrominoes need four matching physical cells")
	await _frames(4)
	game.player.position = Vector2(232, 432)
	_key(game, KEY_F)
	_check(game._carried == package, "Placed packages can be picked up and reorganized")
	game.player.position = Vector2(224, 432)
	game.player.facing = -1
	_key(game, KEY_F)
	await _frames(8)
	_check(package.state == Package.State.READY and game._carried == null, "A carried package can be set aside in reception")
	_check(game.mode == game.Mode.WALKING, "Setting a piece aside must not end the game")
	game.queue_free()
	await process_frame


func _check_full_level() -> void:
	var game := _new_game()
	await _frames(3)
	# Completing the old four-row objective must no longer finish the game.
	for row in [4, 2]:
		for column in range(0, Grid.COLUMNS, 2):
			game.board.place(Shapes.cells(1), column, row, row * 20 + column + 1)
	game._update_counter()
	_check(game.board.completed_rows() == 4 and game.mode == game.Mode.WALKING, "Four full rows must not trigger victory")
	var carried := _give_piece(game, 1, 100)
	await _frames(2)
	var visible_box: Rect2 = carried.world_cells()[0]
	_check(is_equal_approx(visible_box.size.x, 32 * carried.scale.x), "Carried collision checks must match the visible scaled piece")
	var contact_boxes: Array[Rect2] = [visible_box]
	_check(not game._crane_space_clear(contact_boxes), "Previously delivered pieces must still count when carried")
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
	_check(current_scene.get_instance_id() != previous_id and current_scene._spawned == 0, "R must restart with an empty warehouse")
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
