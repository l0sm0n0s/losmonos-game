extends Label

var _glow_layers: Array[Label] = []
var _pulse: Tween


func _ready() -> void:
	# Capas blancas detrás de las letras: no requiere HDR ni bloom del motor.
	for radius in [20, 14, 9, 5, 2]:
		var glow := Label.new()
		glow.name = "NeonGlow%d" % radius
		glow.text = text
		glow.horizontal_alignment = horizontal_alignment
		glow.vertical_alignment = vertical_alignment
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.show_behind_parent = true
		glow.add_theme_font_override("font", get_theme_font("font"))
		glow.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
		glow.add_theme_color_override("font_color", Color(1, 1, 1, 0.035))
		glow.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.035 if radius > 5 else 0.13))
		glow.add_theme_constant_override("outline_size", radius)
		glow.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		add_child(glow)
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_glow_layers.append(glow)
	_set_glow(0.12)
	_pulse = create_tween().set_loops()
	_pulse.tween_method(_set_glow, 0.12, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_pulse.tween_interval(0.25)
	_pulse.tween_method(_set_glow, 1.0, 0.12, 0.8).set_trans(Tween.TRANS_SINE)
	_pulse.tween_interval(0.55)


func _set_glow(intensity: float) -> void:
	for layer in _glow_layers:
		layer.modulate.a = intensity
