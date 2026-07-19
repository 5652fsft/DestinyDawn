extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
const MAX_LINES = 3
const LINE_H = 36
const START_Y = 16
const DURATION = 1.5
const FADE_TIME = 0.35

var _lines: Array = []  # Array of {label, tween, timer}

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE

func show_message(msg: String, duration: float = DURATION):
	# create label
	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = 1
	label.vertical_alignment = 0
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.custom_minimum_size = Vector2(700, 30)
	label.position = Vector2(290, START_Y)
	label.z_index = 10
	add_child(label)

	var entry = {"label": label, "tween": null}
	_lines.append(entry)
	
	# if over max, remove earliest
	while _lines.size() > MAX_LINES:
		var oldest = _lines.pop_front()
		_kill_entry(oldest)
	
	_reposition()
	
	# fade out after delay
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, FADE_TIME).set_delay(duration)
	entry.tween = tw
	tw.finished.connect(func():
		if _lines.has(entry):
			_lines.erase(entry)
		if is_instance_valid(label):
			label.queue_free()
		_reposition()
	)

func _kill_entry(entry: Dictionary):
	if entry.tween and is_instance_valid(entry.tween):
		entry.tween.kill()
	if entry.label and is_instance_valid(entry.label):
		entry.label.queue_free()

func _reposition():
	for i in range(_lines.size()):
		var label = _lines[i].label
		if is_instance_valid(label):
			label.position = Vector2(290, START_Y + i * LINE_H)
