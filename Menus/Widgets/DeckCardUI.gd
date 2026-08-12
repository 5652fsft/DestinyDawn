extends CardUIBase

var card_id: String = ""
var _type_index: int = -1

signal clicked(cid: String)

# === 差异化参数覆写（构筑卡：更小尺寸 + 更小悬停缩放 + 固定 z 序） ===

func _card_type() -> int:
	return _type_index

func _card_size() -> Vector2i:
	return Vector2i(125, 183)

func _split_y() -> float:
	return CardTheme.DECK_SPLIT_Y

func _hover_scale() -> float:
	return CardTheme.DECK_HOVER_SCALE

func _z_index_hover() -> int:
	return 20

func _z_index_normal() -> int:
	return 5

# 选中高亮时提升层级，避免被相邻卡/分割线遮挡
func _selected_z() -> int:
	return 15

func _ready():
	super()
	_reset_scale()

func setup(cid: String, name_text: String, cost: int, type_text: String, desc: String, type_index: int = -1):
	card_id = cid
	_type_index = type_index
	cost_number.text = str(cost)
	name_label.text = name_text
	desc_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc_label.custom_maximum_size = Vector2(115, -1)
	desc_label.text = desc
	type_label.text = type_text if type_index < 0 else CardTheme.TYPE_TAG_TEXT.get(type_index, type_text)
	pivot_offset = size * 0.5
	_reset_scale()
	_apply_visual_style()
	_load_card_image(cid)

func _reset_scale():
	scale = Vector2(CardTheme.DECK_BASE_SCALE, CardTheme.DECK_BASE_SCALE)
	_base_scale = scale
	_on_hover_exit()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(card_id)

func set_in_deck_mode(in_deck: bool):
	set_selected(in_deck)
	_reset_scale()
