extends Label

var float_speed: float = 30.0
var fade_duration: float = 0.65

func _ready():
	vertical_alignment = 1
	horizontal_alignment = 1
	add_theme_font_size_override("font_size", 34)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

func show_value(value: int, is_heal: bool = false, is_shield: bool = false):
	if is_heal:
		text = "+%d" % value
		add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	elif is_shield:
		text = "+%d" % value
		add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	else:
		text = "-%d" % value
		add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, fade_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration * 0.6).set_delay(fade_duration * 0.4)
	tween.finished.connect(queue_free)
