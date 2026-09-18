extends Control

const GAME_SCENE := "res://scenes/main/Main.tscn"

@onready var menu_panel: Control = $MenuPanel
@onready var start_button: Button = $MenuPanel/Menu/StartButton
@onready var exit_button: Button = $MenuPanel/Menu/ExitButton
@onready var transition: ColorRect = $Transition


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	exit_button.pressed.connect(_exit_game)

	for button in [start_button, exit_button]:
		button.mouse_entered.connect(button.grab_focus)

	start_button.grab_focus()
	_animate_entrance()


func _animate_entrance() -> void:
	menu_panel.modulate.a = 0.0
	menu_panel.position.x -= 26.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.42)
	tween.tween_property(menu_panel, "position:x", menu_panel.position.x + 26.0, 0.42)


func _start_game() -> void:
	start_button.disabled = true
	exit_button.disabled = true
	transition.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(transition, "color:a", 1.0, 0.28)
	await tween.finished
	get_tree().change_scene_to_file(GAME_SCENE)


func _exit_game() -> void:
	get_tree().quit()
