extends Node

# Keep gameplay coordinates constant; only the presentation follows the display.
const BASE_SIZE := Vector2i(960, 540)
const WINDOW_FRACTION := 0.9

var _screen := -1
var _usable_rect := Rect2i()
var _poll_time := 0.0
var _desktop := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var window := get_window()
	window.content_scale_size = BASE_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_desktop = DisplayServer.get_name() != "headless" and OS.has_feature("pc")
	if _desktop:
		call_deferred("_refresh_screen", true)


func _process(delta: float) -> void:
	if not _desktop:
		return
	_poll_time += delta
	if _poll_time >= 1.0:
		_poll_time = 0.0
		_refresh_screen()


func _refresh_screen(force: bool = false) -> void:
	var screen := get_window().current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	if not force and screen == _screen and usable == _usable_rect:
		return
	_screen = screen
	_usable_rect = usable
	if get_window().mode == Window.MODE_WINDOWED:
		_fit_window()


static func fitted_size(available: Vector2i) -> Vector2i:
	# Fit an exact 16:9 rectangle, leaving room for borders and the title bar.
	var units := maxi(1, floori(minf(available.x * WINDOW_FRACTION / 16.0,
		available.y * WINDOW_FRACTION / 9.0)))
	return Vector2i(16, 9) * units


func _fit_window() -> void:
	if not _usable_rect.has_area():
		return
	var window := get_window()
	window.size = fitted_size(_usable_rect.size)
	window.position = _usable_rect.position + (_usable_rect.size - window.size) / 2


func _input(event: InputEvent) -> void:
	if not _desktop:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if not _desktop:
		return
	var window := get_window()
	if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		window.mode = Window.MODE_WINDOWED
		# Let the window manager finish changing mode before resizing.
		call_deferred("_refresh_screen", true)
	else:
		window.mode = Window.MODE_FULLSCREEN
