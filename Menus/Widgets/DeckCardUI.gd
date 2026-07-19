extends Panel

const CardTheme = preload("res://UI/CardTheme.gd")

var card_id: String = ""
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE
var _in_deck: bool = false

signal clicked(cid: String)

func setup(cid: String, name_text: String, cost: int, type_text: String, desc: String):
	card_id = cid
	$CostCircle/CostNumber.text = str(cost)
	$NameLabel.text = name_text
	$DescLabel.text = desc
	$TypeLabel.text = type_text
	_reset_scale()
	pivot_offset = size * 0.5
	_apply_style()

func _apply_style():
	# 费用圈
	var c = StyleBoxFlat.new()
	c.bg_color = CardTheme.COST_BG
	c.corner_radius_top_left = CardTheme.COST_RADIUS
	c.corner_radius_top_right = CardTheme.COST_RADIUS
	c.corner_radius_bottom_left = CardTheme.COST_RADIUS
	c.corner_radius_bottom_right = CardTheme.COST_RADIUS
	$CostCircle.add_theme_stylebox_override("panel", c)
	# 卡牌背景
	var p = StyleBoxFlat.new()
	p.bg_color = CardTheme.CARD_BG
	p.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	add_theme_stylebox_override("panel", p)

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	pivot_offset = size * 0.5
	z_index = 5
	_reset_scale()

func _reset_scale():
	scale = Vector2(CardTheme.DECK_BASE_SCALE, CardTheme.DECK_BASE_SCALE)
	_base_scale = scale

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
