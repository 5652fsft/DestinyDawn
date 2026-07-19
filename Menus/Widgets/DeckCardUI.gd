extends Panel

var card_id: String = ""
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE

# drag state
var _is_dragging: bool = false
var _drag_root: Node = null
var _original_parent: Node = null
var _original_sibling: Node = null
var _original_pos: Vector2 = Vector2.ZERO
var _placeholder: Panel = null

signal card_added(cid: String)
signal card_removed(cid: String)
signal card_reordered(cid: String, from_index: int, to_index: int)
signal card_double_clicked(cid: String)

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

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()
		elif _is_dragging:
			_end_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if _is_dragging:
			_cancel_drag()
	elif event is InputEventMouseButton and event.double_click:
		card_double_clicked.emit(card_id)

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if _is_dragging:
			_cancel_drag()

func _start_drag():
	_is_dragging = true
	_drag_root = get_tree().current_scene
	_original_parent = get_parent()
	_original_pos = global_position
	# record the sibling AFTER us (for insertion order)
	var siblings = _original_parent.get_children()
	var my_idx = siblings.find(self)
	_original_sibling = siblings[my_idx + 1] if my_idx + 1 < siblings.size() else null
	# create placeholder ghost at original position
	_placeholder = Panel.new()
	_placeholder.custom_minimum_size = size
	_placeholder.size = size
	_placeholder.modulate = Color(1, 1, 1, 0.15)
	_placeholder.mouse_filter = MOUSE_FILTER_IGNORE
	_original_parent.add_child(_placeholder)
	if _original_sibling:
		_placeholder.get_parent().move_child(_placeholder, _placeholder.get_index())
	else:
		_original_parent.move_child(_placeholder, my_idx)
	# reparent self to scene root for free movement
	if _drag_root:
		reparent(_drag_root)
		global_position = _original_pos
	z_index = 50

func _end_drag():
	_is_dragging = false
	z_index = 5
	_clear_target_highlights()
	
	var deck_grid = get_node_or_null("/root/DeckBuilder/VBoxContainer/DeckPanel/DeckGrid")
	var pool_grid = get_node_or_null("/root/DeckBuilder/VBoxContainer/CardPool/PoolScroll/GridContainer")
	var drop_pos = get_global_rect().get_center()
	var in_deck = deck_grid and deck_grid.get_global_rect().has_point(drop_pos)
	var in_pool = pool_grid and pool_grid.get_global_rect().has_point(drop_pos)
	
	var from_deck = _original_parent == deck_grid
	
	if in_deck and not from_deck:
		# pool→deck: add to deck
		_do_valid_drop(deck_grid)
		card_added.emit(card_id)
	elif in_pool and from_deck:
		# deck→pool: remove from deck
		_do_valid_drop(pool_grid)
		card_removed.emit(card_id)
	elif in_deck and from_deck:
		# deck内部重排
		var target_idx = _find_nearest_slot(deck_grid)
		_do_valid_drop(deck_grid)
		if target_idx >= 0:
			deck_grid.move_child(self, min(target_idx, deck_grid.get_child_count() - 1))
		card_reordered.emit(card_id, _find_index_in_parent(_original_parent, _placeholder), target_idx)
	else:
		# 无效区域：回弹动画
		_return_to_origin()

func _do_valid_drop(new_parent: Node):
	_cleanup_placeholder()
	new_parent.add_child(self)
	# clear old style
	modulate = Color(1, 1, 1, 1)
	_original_parent = new_parent

func _return_to_origin():
	if _placeholder and is_instance_valid(_placeholder):
		var target_pos = _placeholder.global_position
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "global_position", target_pos, 0.2)
		tw.finished.connect(_return_finished)
	else:
		_cleanup_and_return()

func _return_finished():
	_cleanup_and_return()

func _cleanup_and_return():
	z_index = 5
	_cleanup_placeholder()
	if _original_parent:
		reparent(_original_parent)
		if _original_sibling and _original_sibling.get_parent() == _original_parent:
			_original_parent.move_child(self, _original_sibling.get_index())
		global_position = _original_pos

func _cancel_drag():
	_is_dragging = false
	z_index = 5
	_clear_target_highlights()
	_show_toast("已取消操作")
	_return_to_origin()

func _cleanup_placeholder():
	if _placeholder and is_instance_valid(_placeholder):
		_placeholder.queue_free()
		_placeholder = null

# ── target highlight system ──
var _highlighted_slots: Array = []

func _process(_delta):
	if not _is_dragging:
		return
	# update highlight for deck slots
	var deck_grid = get_node_or_null("/root/DeckBuilder/VBoxContainer/DeckPanel/DeckGrid")
	_clear_target_highlights()
	if deck_grid:
		var drop_pos = get_global_rect().get_center()
		for c in deck_grid.get_children():
			if c == self or c == _placeholder: continue
			if c.get_global_rect().has_point(drop_pos):
				_set_slot_highlight(c, true)
			# Also check the grid's column positions
		# check empty slot positions
		var found = false
		for i in range(deck_grid.get_child_count()):
			var child = deck_grid.get_child(i)
			if child.get_global_rect().has_point(drop_pos):
				found = true
				break
		if not found:
			# hovering over empty area between slots — find nearest slot
			pass

func _set_slot_highlight(slot: Node, valid: bool):
	if not slot or slot == self: return
	if valid:
		slot.modulate = Color(0.8, 1.0, 0.8, 1)
		if not slot in _highlighted_slots:
			_highlighted_slots.append(slot)
	else:
		slot.modulate = Color(1.0, 0.6, 0.6, 1)
		if not slot in _highlighted_slots:
			_highlighted_slots.append(slot)

func _clear_target_highlights():
	for s in _highlighted_slots:
		if is_instance_valid(s):
			s.modulate = Color(1, 1, 1, 1)
	_highlighted_slots.clear()

func _find_nearest_slot(grid: GridContainer) -> int:
	if not grid: return -1
	var center = get_global_rect().get_center()
	var best_idx = -1
	var best_dist = 999999.0
	for i in range(grid.get_child_count()):
		var child = grid.get_child(i)
		if child and child.visible and child != self and child != _placeholder:
			var dist = child.get_global_rect().get_center().distance_squared_to(center)
			if dist < best_dist:
				best_dist = dist
				best_idx = i
	return best_idx

func _find_index_in_parent(parent: Node, node: Node) -> int:
	if not parent or not node: return -1
	return parent.get_children().find(node)

func _show_toast(msg: String):
	var main = get_tree().current_scene
	if main and main.has_method("show_toast"):
		main.show_toast(msg, 1.0)

# ── hover effects ──
func set_in_deck_mode(in_deck: bool):
	modulate = Color(1, 1, 1, 1) if in_deck else Color(0.6, 0.6, 0.6, 1)

func _on_hover_enter():
	if _is_dragging: return
	if _hover_tween: _hover_tween.kill()
	z_index = 20
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.15, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color(1, 1, 0.9), 0.12)

func _on_hover_exit():
	if _is_dragging: return
	if _hover_tween: _hover_tween.kill()
	z_index = 5
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
