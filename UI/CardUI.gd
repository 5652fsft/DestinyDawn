class_name CardUI
extends CardUIBase

var card_data: CardData = null

var _is_dragging: bool = false
var _drag_threshold: float = 15.0
var _press_start_pos: Vector2 = Vector2.ZERO
var _ghost: Panel = null

func _card_type() -> int:
	return card_data.card_type if card_data else 0

func setup(data: CardData):
	card_data = data
	cost_number.text = str(data.cost)
	name_label.text = data.card_name
	desc_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc_label.custom_maximum_size = Vector2(128, -1)
	desc_label.text = data.description
	type_label.text = CardTheme.TYPE_TAG_TEXT.get(data.card_type, "UNKNOWN")
	_apply_visual_style()
	_load_card_image(data.id)

# 视觉灰化：仅降明度，透明度保持 1（外观变化，不影响任何交互逻辑）
func set_affordable(can_afford: bool):
	set_disabled_visual(not can_afford)

func get_affordable() -> bool:
	return not get_disabled_visual()

# --- 以下交互逻辑与原始版本完全一致 ---

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_start_pos = get_global_mouse_position()
			_is_dragging = false
		elif _is_dragging:
			_drop_card()
			accept_event()
		else:
			_press_start_pos = Vector2.ZERO
			accept_event()

func _process(delta):
	if _press_start_pos != Vector2.ZERO and not _is_dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var dist = get_global_mouse_position().distance_to(_press_start_pos)
			if dist > _drag_threshold:
				_is_dragging = true
				_start_drag()
	if _is_dragging and _ghost:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drop_card()
		else:
			_ghost.global_position = get_global_mouse_position() - _ghost.size * _ghost.scale * 0.5

func _start_drag():
	_create_ghost()

func _create_ghost():
	_ghost = duplicate(2)
	_ghost.set_script(null)
	_ghost.mouse_filter = MOUSE_FILTER_IGNORE
	_ghost.scale = _base_scale
	_ghost.modulate = Color(1, 1, 1, 0.8)
	_ghost.self_modulate = Color.WHITE

	var main = get_tree().current_scene
	if main and main.has_node("UI"):
		main.get_node("UI").add_child(_ghost)

func _drop_card():
	_press_start_pos = Vector2.ZERO
	if _is_dragging:
		_is_dragging = false
		var main = get_tree().current_scene
		if main and main.has_method("on_card_dropped"):
			if main.on_card_dropped(card_data):
				if _ghost:
					_ghost.z_index = 100
					var tween = get_tree().create_tween().set_parallel(true)
					tween.tween_property(_ghost, "scale", _ghost.scale * 0.3, 0.25)
					tween.tween_property(_ghost, "modulate:a", 0.0, 0.25)
					tween.tween_property(_ghost, "rotation", 0.5, 0.25)
					tween.finished.connect(func():
						if _ghost:
							_ghost.queue_free()
							_ghost = null
					)
				queue_free()
				return
	if _ghost:
		_ghost.queue_free()
		_ghost = null
