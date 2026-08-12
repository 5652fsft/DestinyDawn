class_name CardUIBase
extends Panel

# 战斗卡牌（CardUI）与构筑卡牌（DeckCardUI）的公共样式基类
# 差异化参数通过 _card_type()/_card_size()/_split_y()/_hover_scale() 等虚方法覆写

const CardTheme = preload("res://UI/CardTheme.gd")

var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2(1, 1)
var _saved_z: int = 0
var _disabled: bool = false

@onready var cost_number: Label = $CostCircle/CostNumber
@onready var name_label: Label = $NameLabel
@onready var desc_label: Label = $DescLabel
@onready var type_label: Label = $TypeLabel
@onready var cost_circle: Panel = $CostCircle
@onready var border_overlay: Panel = $BorderOverlay
@onready var card_image: TextureRect = $CardImage
@onready var card_pattern: TextureRect = $CardPattern
@onready var card_pattern_bottom: TextureRect = $CardPatternBottom
@onready var name_divider: Panel = $NameDivider

var _normal_border_style: StyleBoxFlat = null
var _selected: bool = false

# === 子类可覆写的差异化参数 ===

func _card_type() -> int:
	return 0

func _card_size() -> Vector2i:
	return Vector2i(140, 200)

func _split_y() -> float:
	return CardTheme.SPLIT_Y

func _hover_scale() -> float:
	return CardTheme.HOVER_SCALE

func _z_index_hover() -> int:
	return 10

# 返回 0 表示恢复进入前的 z_index
func _z_index_normal() -> int:
	return 0

# === 公共样式应用 ===

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	_base_scale = scale
	_apply_visual_style()

func _apply_visual_style():
	var ct = _card_type()

	# 整卡撞色背景：上半 类型色->深灰 渐变，下半 高级灰白，硬分割
	var panel_style = StyleBoxTexture.new()
	panel_style.texture = CardArtGenerator.make_card_bg(
		CardTheme.TYPE_GRAD_TOP.get(ct, CardTheme.TYPE_GRAD_TOP[0]),
		CardTheme.GRAD_BOTTOM_DARK, CardTheme.BOTTOM_COLOR,
		_split_y(), _card_size())
	var radius = CardTheme.CARD_BORDER_RADIUS
	panel_style.texture_margin_left = radius
	panel_style.texture_margin_top = radius
	panel_style.texture_margin_right = radius
	panel_style.texture_margin_bottom = radius
	add_theme_stylebox_override("panel", panel_style)

	# 双底纹：卡面区白色六边形网格，白底区深色六边形网格
	card_pattern.texture = CardArtGenerator.make_hex_pattern(
		CardTheme.PATTERN_COLOR, CardTheme.PATTERN_HEX_RADIUS)
	card_pattern.stretch_mode = TextureRect.STRETCH_TILE
	card_pattern_bottom.texture = CardArtGenerator.make_hex_pattern(
		CardTheme.PATTERN_DARK_COLOR, CardTheme.PATTERN_HEX_RADIUS)
	card_pattern_bottom.stretch_mode = TextureRect.STRETCH_TILE

	# 外边框（类型色，不透明）
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
		border_style.border_color = Color(bc.r, bc.g, bc.b, 1.0)
	else:
		border_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	border_overlay.add_theme_stylebox_override("panel", border_style)
	_normal_border_style = border_style

	# 费用圆
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
	cost_circle.add_theme_stylebox_override("panel", cost_style)

	# 类型标签颜色（深色渐变底上需高对比：亮色 + 黑色描边）
	var tc = CardTheme.TYPE_TAG_COLOR.get(ct, Color(0.9, 0.6, 0.6, 0.95))
	type_label.add_theme_color_override("font_color", tc)
	type_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	type_label.add_theme_constant_override("outline_size", 1)

	# 卡名上方分割线：与边框同源（TYPE_BORDER 属性颜色，不透明）
	var bc = CardTheme.TYPE_BORDER.get(ct, Color(0.45, 0.2, 0.2, 0.8))
	var divider_style = StyleBoxFlat.new()
	divider_style.bg_color = Color(bc.r, bc.g, bc.b, 1.0)
	divider_style.corner_radius_top_left = 2
	divider_style.corner_radius_top_right = 2
	divider_style.corner_radius_bottom_left = 2
	divider_style.corner_radius_bottom_right = 2
	name_divider.add_theme_stylebox_override("panel", divider_style)

func _load_card_image(card_id: String):
	var path = "res://Assets/Sprites/Cards/%s.png" % card_id
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			card_image.texture = tex
	else:
		card_image.texture = null
		var placeholder = ColorRect.new()
		var ct = _card_type()
		if CardTheme.TYPE_TAG_COLOR.has(ct):
			placeholder.color = Color(CardTheme.TYPE_TAG_COLOR[ct].r, CardTheme.TYPE_TAG_COLOR[ct].g, CardTheme.TYPE_TAG_COLOR[ct].b, 0.15)
		else:
			placeholder.color = Color(0.2, 0.2, 0.25, 0.3)
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_image.add_child(placeholder)

# === 灰化：仅降明度，透明度保持 1 ===

func set_disabled_visual(disabled: bool):
	_disabled = disabled
	modulate = CardTheme.DISABLED_MODULATE if disabled else Color.WHITE

func get_disabled_visual() -> bool:
	return _disabled

# === 选中态：青色高亮框（不灰化、无晕影、提升 z 不被相邻元素遮挡） ===

func set_selected(selected: bool):
	_selected = selected
	if not _normal_border_style:
		return
	if selected:
		# 从正常样式复制出高亮样式，避免污染正常样式（否则取消选中后无法恢复）
		var hl: StyleBoxFlat = _normal_border_style.duplicate()
		hl.border_color = CardTheme.SELECT_BORDER_COLOR
		hl.border_width_top = 3
		hl.border_width_bottom = 3
		hl.border_width_left = 3
		hl.border_width_right = 3
		border_overlay.add_theme_stylebox_override("panel", hl)
		if _selected_z() > 0:
			z_index = _selected_z()
	else:
		border_overlay.add_theme_stylebox_override("panel", _normal_border_style)
		if _selected_z() > 0:
			z_index = _z_index_normal()

func get_selected() -> bool:
	return _selected

# 选中时的 z 层级（0 = 不改变 z，用于战斗卡等无选中态的卡）
func _selected_z() -> int:
	return 0

# === 公共 hover 动画 ===

func _on_hover_enter():
	if _hover_tween:
		_hover_tween.kill()
	_saved_z = z_index
	z_index = _z_index_hover()
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * _hover_scale(), CardTheme.HOVER_TWEEN_SEC)
	if not _disabled:
		_hover_tween.parallel().tween_property(self, "self_modulate", CardTheme.HOVER_MODULATE, CardTheme.HOVER_TWEEN_SEC)

func _on_hover_exit():
	if _hover_tween:
		_hover_tween.kill()
	if _selected and _selected_z() > 0:
		z_index = _selected_z()
	else:
		var normal_z = _z_index_normal()
		z_index = _saved_z if normal_z == 0 else normal_z
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, CardTheme.HOVER_TWEEN_SEC)
	var restore = Color.WHITE if not _disabled else CardTheme.DISABLED_MODULATE
	_hover_tween.parallel().tween_property(self, "self_modulate", restore, CardTheme.HOVER_TWEEN_SEC)
