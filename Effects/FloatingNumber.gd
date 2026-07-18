extends Label

var float_speed: float = 80.0
var fade_duration: float = 0.4

func _ready():
	vertical_alignment = 1
	horizontal_alignment = 1
	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", Color.WHITE)

func show_value(value: int, is_heal: bool = false, is_shield: bool = false):
	if is_heal:
		text = "+%d" % value
		add_theme_color_override("font_color", Color(0.0, 1.0, 0.25))
	elif is_shield:
		text = "+%d" % value
		add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	else:
		text = "-%d" % value
		add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, fade_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration * 0.6).set_delay(fade_duration * 0.4)
	tween.finished.connect(queue_free)
