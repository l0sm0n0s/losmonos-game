extends SceneTree

const Display = preload("res://scripts/system/display_manager.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func press_f11() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F11
	event.physical_keycode = KEY_F11
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	for available in [Vector2i(1920, 1040), Vector2i(2560, 1400), Vector2i(3840, 2120),
		Vector2i(3440, 1400), Vector2i(1280, 984), Vector2i(1080, 1880), Vector2i(640, 440)]:
		var size := Display.fitted_size(available)
		check(size.x <= available.x * 0.9 and size.y <= available.y * 0.9, "Window must fit the usable monitor area")
		check(size.x * 9 == size.y * 16, "Window must preserve the game aspect ratio")
		check(size.x > 0 and size.y > 0, "Small displays must have a valid window")
	check(Display.fitted_size(Vector2i(3840, 2120)).x > 960, "High resolution monitors must get a larger window")
	await process_frame
	var manager := root.get_node("DisplayManager")
	check(root.content_scale_size == Vector2i(960, 540), "Gameplay coordinates must remain unchanged")
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Resizing must not crop or distort the game")
	if DisplayServer.get_name() != "headless":
		manager._refresh_screen(true)
		await create_timer(0.2).timeout
		var usable := DisplayServer.screen_get_usable_rect(root.current_screen)
		check(root.size == Display.fitted_size(usable.size), "Startup must fit the detected monitor")
		check(usable.encloses(Rect2i(root.position, root.size)), "Centered window must stay on its monitor")
		root.size = Vector2i(800, 600)
		await create_timer(1.2).timeout
		check(root.size == Vector2i(800, 600), "Polling must preserve a manual window resize")
		var menu := load("res://scenes/ui/StartMenu.tscn").instantiate() as Control
		root.add_child(menu)
		await process_frame
		await press_f11()
		await create_timer(0.3).timeout
		check(root.mode == Window.MODE_FULLSCREEN, "F11 must enter fullscreen")
		await press_f11()
		await create_timer(0.3).timeout
		check(root.mode == Window.MODE_WINDOWED and root.size == Display.fitted_size(usable.size), "Leaving fullscreen must restore a fitting window")
		menu.queue_free()
		await process_frame
		var game := load("res://scenes/main/Main.tscn").instantiate() as Node2D
		root.add_child(game)
		await process_frame
		await press_f11()
		await create_timer(0.3).timeout
		check(root.mode == Window.MODE_FULLSCREEN, "F11 must also work during gameplay")
		await press_f11()
		await create_timer(0.3).timeout
		check(root.mode == Window.MODE_WINDOWED, "F11 must leave fullscreen during gameplay")
		game.queue_free()
		await process_frame
	print("Display checks: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(0 if failures == 0 else 1)
