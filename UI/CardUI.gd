class_name CardUI
extends Panel

const CardTheme = preload("res://UI/CardTheme.gd")

var card_data: CardData = null

var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2(1, 1)
var _saved_z: int = 0

var _is_dragging: bool = false
var _drag_threshold: float = 15.0
var _press_start_pos: Vector2 = Vector2.ZERO
var _ghost: Panel = null
var _saved_rotation: float = 0.0
var _affordable: bool = true

@onready var cost_number: Label = $CostCircle/CostNumber
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var type_label: Label = $TypeLabel
@onready var cost_circle: Panel = $CostCircle
@onready var border_overlay: Panel = $BorderOverlay
@onready var card_image: TextureRect = $CardImage

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	_base_scale = scale

	var style = StyleBoxFlat.new()
	style.bg_color = CardTheme.COST_BG
	style.corner_radius_top_left = CardTheme.COST_RADIUS
	style.corner_radius_top_right = CardTheme.COST_RADIUS
	style.corner_radius_bottom_left = CardTheme.COST_RADIUS
	style.corner_radius_bottom_right = CardTheme.COST_RADIUS
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	cost_circle.add_theme_stylebox_override("panel", style)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = CardTheme.CARD_BG
	panel_style.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	panel_style.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	panel_style.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	panel_style.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	panel_style.shadow_size = 0
	add_theme_stylebox_override("panel", panel_style)

	var border_style = StyleBoxFlat.new()
	border_style.draw_center = false
	border_style.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	border_style.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	border_style.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	border_style.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	border_style.border_width_top = 2
	border_style.border_width_bottom = 2
	border_style.border_width_left = 2
	border_style.border_width_right = 2
	border_style.border_color = Color(0.3, 0.3, 0.35, 0.6)
	border_overlay.add_theme_stylebox_override("panel", border_style)

func setup(data: CardData):
	card_data = data
	cost_number.text = str(data.cost)
	name_label.text = data.card_name
	desc_label.text = data.description

	var ct = data.card_type
	type_label.text = CardTheme.TYPE_TAG_TEXT.get(ct, "UNKNOWN")
	if CardTheme.TYPE_TAG_COLOR.has(ct):
		type_label.add_theme_color_override("font_color", CardTheme.TYPE_TAG_COLOR[ct])

	var cost_style: StyleBoxFlat = cost_circle.get_theme_stylebox("panel") as StyleBoxFlat
	if cost_style and CardTheme.TYPE_COST_BG.has(ct):
		cost_style.bg_color = CardTheme.TYPE_COST_BG[ct]
		cost_style.border_color = Color(CardTheme.TYPE_TAG_COLOR[ct].r, CardTheme.TYPE_TAG_COLOR[ct].g, CardTheme.TYPE_TAG_COLOR[ct].b, 0.4)

	var border_style: StyleBoxFlat = border_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	if border_style and CardTheme.TYPE_BORDER.has(ct):
		var bc = CardTheme.TYPE_BORDER[ct]
		border_style.border_color = Color(bc.r, bc.g, bc.b, 0.7)

	_load_card_image(data.id)

func _load_card_image(card_id: String):
	var path = "res://Assets/Sprites/Cards/%s.png" % card_id
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			card_image.texture = tex
	else:
		card_image.texture = null
		var placeholder = ColorRect.new()
		var ct = card_data.card_type if card_data else 0
		if CardTheme.TYPE_TAG_COLOR.has(ct):
			placeholder.color = Color(CardTheme.TYPE_TAG_COLOR[ct].r, CardTheme.TYPE_TAG_COLOR[ct].g, CardTheme.TYPE_TAG_COLOR[ct].b, 0.15)
		else:
			placeholder.color = Color(0.2, 0.2, 0.25, 0.3)
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_image.add_child(placeholder)

# 视觉灰化：仅控制外观，不影响任何交互逻辑
func set_affordable(can_afford: bool):
	_affordable = can_afford
	if not can_afford:
		self_modulate = Color(0.6, 0.6, 0.65, CardTheme.DISABLED_ALPHA)
	else:
		self_modulate = Color.WHITE

func get_affordable() -> bool:
	return _affordable

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

func _on_hover_enter():
	if _hover_tween:
		_hover_tween.kill()
	_saved_z = z_index
	z_index = 10
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * CardTheme.HOVER_SCALE, CardTheme.HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(self, "self_modulate", CardTheme.HOVER_MODULATE, CardTheme.HOVER_TWEEN_SEC)

	var panel_style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style:
		panel_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
		panel_style.shadow_size = CardTheme.HOVER_SHADOW_SIZE
		panel_style.shadow_color = CardTheme.HOVER_SHADOW_COLOR
		panel_style.shadow_offset = CardTheme.HOVER_SHADOW_OFFSET

func _on_hover_exit():
	if _hover_tween:
		_hover_tween.kill()
	z_index = _saved_z
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, CardTheme.HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, CardTheme.HOVER_TWEEN_SEC)

	var panel_style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style:
		panel_style.bg_color = CardTheme.CARD_BG
		panel_style.shadow_size = 0
