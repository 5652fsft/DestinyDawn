extends Panel

const CardTheme = preload("res://UI/CardTheme.gd")

var card_id: String = ""
var _card_type: int = -1
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE
var _in_deck: bool = false

signal clicked(cid: String)

func setup(cid: String, name_text: String, cost: int, type_text: String, desc: String, type_index: int = -1):
	card_id = cid
	_card_type = type_index
	$CostCircle/CostNumber.text = str(cost)
	$MarginContainer/VBoxContainer/NameLabel.text = name_text
	$MarginContainer/VBoxContainer/DescLabel.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	$MarginContainer/VBoxContainer/DescLabel.custom_maximum_size = Vector2(116, -1)
	$MarginContainer/VBoxContainer/DescLabel.text = desc
	$TypeLabel.text = type_text if type_index < 0 else CardTheme.TYPE_TAG_TEXT.get(type_index, type_text)
	_reset_scale()
	pivot_offset = size * 0.5
	_apply_style()
	_load_card_image(cid)

func _apply_style():
	var ct = _card_type

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
	if CardTheme.TYPE_BORDER.has(ct):
		var bc = CardTheme.TYPE_BORDER[ct]
		border_style.border_color = Color(bc.r, bc.g, bc.b, 0.7)
	else:
		border_style.border_color = Color(0.3, 0.3, 0.35, 0.6)
	$BorderOverlay.add_theme_stylebox_override("panel", border_style)

	var cost_style = StyleBoxFlat.new()
	cost_style.bg_color = CardTheme.COST_BG
	cost_style.corner_radius_top_left = CardTheme.COST_RADIUS
	cost_style.corner_radius_top_right = CardTheme.COST_RADIUS
	cost_style.corner_radius_bottom_left = CardTheme.COST_RADIUS
	cost_style.corner_radius_bottom_right = CardTheme.COST_RADIUS
	cost_style.border_width_top = 1
	cost_style.border_width_bottom = 1
	cost_style.border_width_left = 1
	cost_style.border_width_right = 1
	if CardTheme.TYPE_COST_BG.has(ct):
		cost_style.bg_color = CardTheme.TYPE_COST_BG[ct]
		cost_style.border_color = Color(CardTheme.TYPE_TAG_COLOR[ct].r, CardTheme.TYPE_TAG_COLOR[ct].g, CardTheme.TYPE_TAG_COLOR[ct].b, 0.4)
	else:
		cost_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	$CostCircle.add_theme_stylebox_override("panel", cost_style)

	if CardTheme.TYPE_TAG_COLOR.has(ct):
		$TypeLabel.add_theme_color_override("font_color", CardTheme.TYPE_TAG_COLOR[ct])

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = CardTheme.CARD_BG
	panel_style.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	panel_style.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	panel_style.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	panel_style.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	panel_style.shadow_size = 0
	add_theme_stylebox_override("panel", panel_style)

func _load_card_image(card_id: String):
	var path = "res://Assets/Sprites/Cards/%s.png" % card_id
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			$CardImage.texture = tex
	else:
		$CardImage.texture = null
		var placeholder = ColorRect.new()
		var ct = _card_type
		if CardTheme.TYPE_TAG_COLOR.has(ct):
			placeholder.color = Color(CardTheme.TYPE_TAG_COLOR[ct].r, CardTheme.TYPE_TAG_COLOR[ct].g, CardTheme.TYPE_TAG_COLOR[ct].b, 0.15)
		else:
			placeholder.color = Color(0.2, 0.2, 0.25, 0.3)
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$CardImage.add_child(placeholder)

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	pivot_offset = size * 0.5
	z_index = 5
	_reset_scale()
	_apply_style()

func _reset_scale():
	scale = Vector2(CardTheme.DECK_BASE_SCALE, CardTheme.DECK_BASE_SCALE)
	_base_scale = scale
	_on_hover_exit()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(card_id)

func set_in_deck_mode(in_deck: bool):
	_in_deck = in_deck
	modulate = Color(1, 1, 1, 1) if in_deck else Color(CardTheme.DISABLED_ALPHA, CardTheme.DISABLED_ALPHA, CardTheme.DISABLED_ALPHA, 1)
	_reset_scale()

func _on_hover_enter():
	if _hover_tween: _hover_tween.kill()
	z_index = 20
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * CardTheme.DECK_HOVER_SCALE, CardTheme.HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(self, "self_modulate", CardTheme.HOVER_MODULATE, CardTheme.HOVER_TWEEN_SEC)

func _on_hover_exit():
	if _hover_tween: _hover_tween.kill()
	z_index = 5
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, CardTheme.HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, CardTheme.HOVER_TWEEN_SEC)
