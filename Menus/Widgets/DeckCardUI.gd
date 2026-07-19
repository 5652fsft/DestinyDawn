extends Panel

var card_id: String = ""
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE
var _drag_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _original_parent: Control = null
var _original_index: int = -1

signal card_added(cid: String)
signal card_removed(cid: String)
signal card_reordered(cid: String, from_index: int, to_index: int)

func setup(cid: String, name_text: String, cost: int, type_text: String, desc: String):
	card_id = cid
	$CostCircle/CostNumber.text = str(cost)
	$NameLabel.text = name_text
	$DescLabel.text = desc
	$TypeLabel.text = type_text
	_base_scale = scale

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 0
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_offset = get_local_mouse_position()
			_is_dragging = true
		elif _is_dragging:
			_is_dragging = false
			_drop_card()

func _process(_delta):
	if _is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		global_position = get_global_mouse_position() - _drag_offset * scale
		z_index = 100

func _drop_card():
	z_index = 0
	var deck_panel = get_node_or_null("/root/DeckBuilder/HBoxContainer/DeckPanel/DeckScroll/DeckGrid")
	var pool_scroll = get_node_or_null("/root/DeckBuilder/HBoxContainer/CardPool/PoolScroll/GridContainer")
	
	var drop_pos = get_global_rect().get_center()
	var in_deck = deck_panel and deck_panel.get_global_rect().has_point(drop_pos)
	var in_pool = pool_scroll and pool_scroll.get_global_rect().has_point(drop_pos)
	
	var parent_name = get_parent().name if get_parent() else ""
	var is_from_deck = parent_name == "DeckGrid"
	
	if in_deck and not is_from_deck:
		card_added.emit(card_id)
	elif in_pool and is_from_deck:
		card_removed.emit(card_id)
	else:
		# 同区域拖动：重新排序
		if is_from_deck:
			var target_slot = _find_nearest_slot(deck_panel)
			if target_slot != _original_index and target_slot >= 0:
				card_reordered.emit(card_id, _original_index, target_slot)
		# 如果没放到有效区域，回到原位
		if _original_parent:
			_original_parent.add_child(self)
			if _original_index >= 0 and _original_parent.get_child_count() > _original_index:
				_original_parent.move_child(self, _original_index)

func _find_nearest_slot(grid: GridContainer) -> int:
	if not grid:
		return -1
	var center = get_global_rect().get_center()
	var best_idx = -1
	var best_dist = 999999.0
	for i in range(grid.get_child_count()):
		var child = grid.get_child(i)
		if child and child.visible:
			var dist = child.get_global_rect().get_center().distance_squared_to(center)
			if dist < best_dist:
				best_dist = dist
				best_idx = i
	return best_idx

func set_in_deck_mode(in_deck: bool):
	modulate = Color(1, 1, 1, 1) if in_deck else Color(0.6, 0.6, 0.6, 1)

func _on_hover_enter():
	if _hover_tween:
		_hover_tween.kill()
	z_index = 10
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.15, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color(1, 1, 0.9), 0.12)

func _on_hover_exit():
	if _hover_tween:
		_hover_tween.kill()
	z_index = 0
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
