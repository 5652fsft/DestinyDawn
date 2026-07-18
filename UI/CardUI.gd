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

@onready var cost_label: Label = $MarginContainer/VBoxContainer/TopRow/CostLabel
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var type_label: Label = $MarginContainer/VBoxContainer/TopRow/TypeLabel

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
