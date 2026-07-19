extends Panel

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
	_base_scale = scale
	pivot_offset = size * 0.5

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	pivot_offset = size * 0.5
	z_index = 5

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(card_id)

func set_in_deck_mode(in_deck: bool):
	_in_deck = in_deck
	modulate = Color(1, 1, 1, 1) if in_deck else Color(0.6, 0.6, 0.6, 1)

func _on_hover_enter():
	if _hover_tween: _hover_tween.kill()
	z_index = 20
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.15, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color(1, 1, 0.9), 0.12)

func _on_hover_exit():
	if _hover_tween: _hover_tween.kill()
	z_index = 5
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.12)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
