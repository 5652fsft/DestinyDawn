class_name CardUI
extends Panel

var card_data: CardData = null
signal card_drag_started(card: CardUI)

var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2(1, 1)

var _is_dragging: bool = false
var _drag_threshold: float = 15.0
var _press_start_pos: Vector2 = Vector2.ZERO
var _ghost: Panel = null
var _restore_y: float = 0.0

@onready var cost_number: Label = $CostCircle/CostNumber
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var type_label: Label = $TypeLabel
@onready var cost_circle: ColorRect = $CostCircle

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	_base_scale = scale

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	cost_circle.add_theme_stylebox_override("panel", style)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_size = 0
	add_theme_stylebox_override("panel", panel_style)

func setup(data: CardData):
	card_data = data
	cost_number.text = str(data.cost)
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

func _cleanup_ghost():
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _on_hover_enter():
	if _hover_tween:
		_hover_tween.kill()
	_restore_y = position.y
	z_index = 10
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.25, 0.12)
	_hover_tween.parallel().tween_property(self, "rotation", 0.03, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color(1, 1, 0.85), 0.12)
	_hover_tween.parallel().tween_property(self, "position:y", _restore_y - 80.0, 0.12)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_size = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_offset = Vector2(4, 4)
	add_theme_stylebox_override("panel", panel_style)

func _on_hover_exit():
	if _hover_tween:
		_hover_tween.kill()
	z_index = 0
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.12)
	_hover_tween.parallel().tween_property(self, "rotation", 0.0, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
	_hover_tween.parallel().tween_property(self, "position:y", _restore_y, 0.12)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_size = 0
	add_theme_stylebox_override("panel", panel_style)
