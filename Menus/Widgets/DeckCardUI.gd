extends Panel

var card_id: String = ""
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE
var _is_dragging: bool = false

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
	pivot_offset = size * 0.5

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	pivot_offset = size * 0.5
	z_index = 5
	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 0
	add_theme_stylebox_override("panel", style)

var _drag_root: Node = null

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_root = get_tree().current_scene
			if _drag_root:
				reparent(_drag_root)
		elif _is_dragging:
			_is_dragging = false
			_drop_card()

func _process(_delta):
	if _is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		global_position = get_global_mouse_position() - size * 0.5
		z_index = 50

func _drop_card():
	z_index = 5
	var deck_grid = get_node_or_null("/root/DeckBuilder/VBoxContainer/DeckPanel/DeckGrid")
	var pool_grid = get_node_or_null("/root/DeckBuilder/VBoxContainer/CardPool/PoolScroll/GridContainer")
	
	var drop_pos = get_global_rect().get_center()
	var in_deck = deck_grid and deck_grid.get_global_rect().has_point(drop_pos)
	var in_pool = pool_grid and pool_grid.get_global_rect().has_point(drop_pos)
	
	var parent_name = get_parent().name if get_parent() else ""
	var is_from_deck = parent_name == "DeckGrid"
	
	if in_deck and not is_from_deck:
		if deck_grid:
			reparent(deck_grid)
		card_added.emit(card_id)
	elif in_pool and is_from_deck:
		if pool_grid:
			reparent(pool_grid)
		card_removed.emit(card_id)
	elif in_deck and is_from_deck:
		# 在卡组内重排
		if deck_grid:
			var target_idx = _find_nearest_slot(deck_grid)
			reparent(deck_grid)
			if target_idx >= 0:
				deck_grid.move_child(self, min(target_idx, deck_grid.get_child_count() - 1))
	elif in_pool and not is_from_deck:
		if pool_grid:
			reparent(pool_grid)
	else:
		# 拖到无效区域，回到对应网格
		if is_from_deck and deck_grid:
			reparent(deck_grid)
		elif pool_grid:
			reparent(pool_grid)

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
	z_index = 20
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.15, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color(1, 1, 0.9), 0.12)

func _on_hover_exit():
	if _hover_tween:
		_hover_tween.kill()
	z_index = 5
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
