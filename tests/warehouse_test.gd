extends SceneTree

const Shapes = preload("res://scripts/packages/package_shapes.gd")
const Grid = preload("res://scripts/warehouse/storage_grid.gd")
const Package = preload("res://scripts/packages/package.gd")
const MAIN = preload("res://scenes/main/Main.tscn")
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)


func _run() -> void:
	Engine.time_scale = 12.0
	Engine.max_fps = 120
	_check_shapes_and_grid()
	await _check_full_level()
	await _check_full_rack()
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
	_check(board.landing_row(square, 0) == 6, "Squares must fall to the bottom")
	var before := board.grid.duplicate(true)
	_check(board.place(square, 5, 1) == -1 and board.grid == before, "Out-of-bounds placements must not mutate the grid")
	_check(board.place(square, 0, 1) == 0, "First square should not clear a row")
	_check(board.landing_row(square, 0) == 4, "Preview must stack on occupied cells")
	_check(board.place(square, 2, 1) == 0, "Second square should leave a gap")
	_check(board.place(square, 4, 1) == 2, "Three squares must clear two complete rows")
	for row: Array in board.grid:
		_check(row.count(0) == Grid.COLUMNS, "Cleared rows must be replaced with empty rows")
	board.grid[5][0] = 7
	board.grid[7].fill(1)
	_check(board.place(square, 4, 1) == 1, "Completed bottom row must clear")
	_check(board.grid[6][0] == 7, "Rows above a clear must shift downward")
	board.free()


func _check_full_level() -> void:
	var game = MAIN.instantiate()
	root.add_child(game)
	await create_timer(1.5).timeout
	_check(game.packages.get_child_count() == 1, "The crane must release its first package")
	if game.packages.get_child_count() > 0:
		var first: Package = game.packages.get_child(0)
		_check(first.state == Package.State.FALLING and not first.is_available(), "Falling boxes must not be collectible")
	await create_timer(13.0).timeout
	_check(game._waiting_count() == 3, "Reception must stop at three packages")
	var deliveries: int = game._spawned
	await create_timer(5.0).timeout
	_check(game._spawned == deliveries, "Full reception must pause the crane")
	var columns := [0, 2, 4, 0, 4, 0]
	for index in range(columns.size()):
		var package: Package
		for _attempt in range(80):
			for candidate: Package in game.packages.get_children():
				if candidate.number == index + 1 and candidate.is_available():
					package = candidate
					break
			if package != null:
				break
			await create_timer(0.25).timeout
		_check(package != null, "Missing tutorial package %d" % (index + 1))
		if package == null:
			break
		game.player.position = package.position + Vector2(0, 42)
		game._interact()
		_check(game._carried == package, "The worker must pick up a nearby landed package")
		game.player.position = game.STATION
		game._interact()
		_check(game.mode == game.Mode.PLACING, "Station must enter grid placement mode")
		_check(not game.player.is_physics_processing(), "Grid controls must not move the worker")
		if index == 0:
			var rotate := InputEventKey.new()
			rotate.keycode = KEY_E
			rotate.pressed = true
			game._unhandled_input(rotate)
			_check(game._turns == 1, "E must rotate the held piece")
			game._cancel_placement()
			_check(game._carried == package and game.player.is_physics_processing(), "Cancel must preserve the carried package and restore movement")
			game._begin_placement()
		game._column = columns[index]
		game._update_preview()
		game._place_carried()
		await process_frame
	_check(game.rows_completed == 4, "The tutorial lot must be solvable in six placements")
	_check(game.mode == game.Mode.FINISHED and game.result_overlay.visible, "Four rows must show the victory screen")
	_check(game.spawn_timer.is_stopped() and not game.player.is_physics_processing(), "Victory must stop deliveries and movement")
	game.queue_free()
	await process_frame


func _check_full_rack() -> void:
	var game = MAIN.instantiate()
	root.add_child(game)
	for row: Array in game.board.grid:
		row.fill(1)
	var package: Package = preload("res://scenes/packages/Package.tscn").instantiate()
	game.packages.add_child(package)
	package.state = Package.State.READY
	package.pick_up(game.player.carry_point)
	game._carried = package
	game._begin_placement()
	_check(game.mode == game.Mode.FINISHED, "A piece with no valid rotation must end the attempt")
	_check(game.get_node("HUD/ResultOverlay/Card/Content/Stamp").text == "ESTANTERÍA LLENA", "Overflow must explain why the attempt ended")
	game.queue_free()
	await process_frame


func _check_navigation() -> void:
	change_scene_to_file("res://scenes/ui/StartMenu.tscn")
	await process_frame
	await process_frame
	current_scene.start_button.pressed.emit()
	await create_timer(0.6).timeout
	_check(current_scene.scene_file_path == "res://scenes/main/Main.tscn", "Start button must open the warehouse")
	var game = current_scene
	var previous_id: int = game.get_instance_id()
	for row: Array in game.board.grid:
		row.fill(1)
	var package: Package = preload("res://scenes/packages/Package.tscn").instantiate()
	game.packages.add_child(package)
	package.state = Package.State.READY
	package.pick_up(game.player.carry_point)
	game._carried = package
	game._begin_placement()
	var restart := InputEventKey.new()
	restart.keycode = KEY_R
	restart.pressed = true
	game._unhandled_input(restart)
	await process_frame
	await process_frame
	_check(current_scene.get_instance_id() != previous_id and current_scene.rows_completed == 0, "R must restart a lost level with an empty board")
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
	_check(title.get_child_count() == 5, "Title must have five back-glow layers")
	var original_color := title.get_theme_color("font_color")
	await create_timer(0.3).timeout
	var initial_alpha: float = title.get_child(0).modulate.a
	await create_timer(0.6).timeout
	_check(title.get_child(0).modulate.a > initial_alpha, "White neon must pulse over time")
	_check(title.get_theme_color("font_color") == original_color, "Glow must preserve the blue title")
	menu.queue_free()
	await process_frame
