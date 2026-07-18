extends Control

var card_uis: Array[CardUI] = []

const FAN_ANGLE: float = deg_to_rad(12.0)
const FAN_SPREAD_X: float = 240.0
const FAN_ARC_Y: float = 50.0

@onready var card_container: Control = $CardContainer
@onready var card_scene: PackedScene = preload("res://UI/CardUI.tscn")

func clear():
	for child in card_container.get_children():
		child.queue_free()
	card_uis.clear()

func set_hand(card_ids: Array[String]):
	var existing: Dictionary = {}
	for card in card_uis:
		if card.card_data:
			existing[card.card_data.id] = card
	var ids_set: Dictionary = {}
	for cid in card_ids:
		ids_set[cid] = true
	for i in range(card_uis.size() - 1, -1, -1):
		if card_uis[i].card_data and card_uis[i].card_data.id not in ids_set:
			card_uis[i].queue_free()
			card_uis.remove_at(i)
	var ordered: Array[CardUI] = []
	for cid in card_ids:
		if cid in existing:
			ordered.append(existing[cid])
		else:
			var data = CardDatabase.get_card(cid)
			if data:
				_add_card(data, false)
				ordered.append(card_uis.back())
	card_uis = ordered
	_layout_cards()

func remove_card_via_data(data: CardData) -> bool:
	for i in range(card_uis.size() - 1, -1, -1):
		if card_uis[i].card_data == data:
			var card = card_uis[i]
			card_uis.remove_at(i)
			card.queue_free()
			_layout_cards()
			return true
	return false

func _add_card(data: CardData, animated: bool = true):
	var instance = card_scene.instantiate()
	card_container.add_child(instance)
	instance.setup(data)
	instance.pivot_offset = instance.size * 0.5
	card_uis.append(instance)

	if animated:
		instance.scale = Vector2.ZERO
		instance.modulate.a = 0.0
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(instance, "scale", Vector2.ONE, 0.25)
		tween.parallel().tween_property(instance, "modulate:a", 1.0, 0.15)

func _layout_cards():
	var count = card_uis.size()
	if count == 0:
		return
	var center_x = card_container.size.x * 0.5
	var base_y = card_container.size.y * 0.5
	for i in range(count):
		var card = card_uis[i]
		var t = float(i) / max(count - 1, 1) - 0.5
		var angle = t * FAN_ANGLE
		var target_x = center_x + t * FAN_SPREAD_X
		var target_y = base_y + abs(t) * FAN_ARC_Y - FAN_ARC_Y * 0.5
		var target_rotation = angle
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", Vector2(target_x, target_y), 0.35)
		tween.parallel().tween_property(card, "rotation", target_rotation, 0.35)
