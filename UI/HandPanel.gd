extends Control

var card_uis: Array[CardUI] = []
var selected_card_ui: CardUI = null

signal card_played(card_data: CardData)

@onready var card_container: HBoxContainer = $CardContainer
@onready var card_scene: PackedScene = preload("res://UI/CardUI.tscn")

func clear():
	for child in card_container.get_children():
		child.queue_free()
	card_uis.clear()
	selected_card_ui = null

func set_hand(card_ids: Array[String]):
	clear()
	for i in range(card_ids.size()):
		var cid = card_ids[i]
		var data = CardDatabase.get_card(cid)
		if not data:
			continue
		_add_card(data, i)

func _add_card(data: CardData, index: int = 0):
	var instance = card_scene.instantiate()
	instance.card_clicked.connect(_on_card_clicked)
	card_container.add_child(instance)
	instance.setup(data)
	card_uis.append(instance)

	instance.scale = Vector2.ZERO
	instance.modulate.a = 0.0
	var delay = index * 0.08
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)
	tween.tween_property(instance, "scale", Vector2.ONE, 0.25)
	tween.parallel().tween_property(instance, "modulate:a", 1.0, 0.15)

func _on_card_clicked(card_ui: CardUI):
	if selected_card_ui == card_ui:
		selected_card_ui = null
		card_ui.is_card_selected = false
		return
	if selected_card_ui:
		selected_card_ui.is_card_selected = false
	selected_card_ui = card_ui
	card_ui.is_card_selected = true
	card_played.emit(card_ui.card_data)

func clear_selection():
	if selected_card_ui:
		selected_card_ui.is_card_selected = false
		selected_card_ui = null
