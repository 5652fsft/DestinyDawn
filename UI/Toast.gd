extends Label

var _tween: Tween = null

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

func _ready():
	horizontal_alignment = 1
	vertical_alignment = 0
	add_theme_font_size_override("font_size", 22)
	add_theme_font_override("font", FONT)
	add_theme_color_override("font_color", Color(1, 1, 0.85))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	custom_minimum_size = Vector2(700, 0)
	hide()

func show_message(msg: String, duration: float = 1.5):
	text = msg
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	show()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(duration)
	_tween.finished.connect(_on_finished)

func _on_finished():
	hide()
