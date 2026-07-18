class_name CardUI
extends Panel

var card_data: CardData = null
var is_card_selected: bool = false:
	set(value):
		is_card_selected = value
		if value:
			self_modulate = Color(1, 1, 0.7)
		else:
			self_modulate = Color.WHITE

signal card_clicked(card: CardUI)
signal card_drag_started(card: CardUI)

var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2(1, 1)
var _is_dragging: bool = false
var _drag_threshold: float = 15.0
var _press_start_pos: Vector2 = Vector2.ZERO
var _ghost: Panel = null

@onready var cost_label: Label = $MarginContainer/VBoxContainer/TopRow/CostLabel
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var type_label: Label = $MarginContainer/VBoxContainer/TopRow/TypeLabel

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	_base_scale = scale

func setup(data: CardData):
	card_data = data
	cost_label.text = "费用: %d" % data.cost
	name_label.text = data.card_name
	desc_label.text = data.description
	type_label.text = CardData.CardType.keys()[data.card_type]

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
			card_clicked.emit(self)
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
	card_drag_started.emit(self)

func _create_ghost():
	_ghost = Panel.new()
	_ghost.size = size
	_ghost.scale = _base_scale * 1.15
	_ghost.modulate = Color(1, 1, 1, 0.85)
	_ghost.mouse_filter = MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_ghost.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = card_data.card_name if card_data else ""
	lbl.horizontal_alignment = 1
	lbl.vertical_alignment = 1
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	_ghost.add_child(lbl)
	
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
					var tween = create_tween().set_parallel(true)
					tween.tween_property(_ghost, "scale", _ghost.scale * 0.3, 0.25)
					tween.tween_property(_ghost, "modulate:a", 0.0, 0.25)
					tween.tween_property(_ghost, "rotation", 0.5, 0.25)
					tween.finished.connect(_cleanup_ghost)
					return
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _cleanup_ghost():
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _on_hover_enter():
	if _hover_tween:
		_hover_tween.kill()
	z_index = 10
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.12, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color(1, 1, 0.85), 0.12)

func _on_hover_exit():
	if _hover_tween:
		_hover_tween.kill()
	z_index = 0
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.12)
	if not is_card_selected:
		_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
