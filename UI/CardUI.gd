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

var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2(1, 1)

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(self)
		accept_event()

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
