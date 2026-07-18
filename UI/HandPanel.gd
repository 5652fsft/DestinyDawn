extends Control

var card_uis: Array[CardUI] = []

const MAX_FAN_ANGLE: float = deg_to_rad(12.0)
const MAX_FAN_SPREAD: float = 280.0
const FAN_ARC_Y: float = 50.0
const TARGET_GAP: float = 100.0

@onready var card_container: Control = $CardContainer
@onready var card_scene: PackedScene = preload("res://UI/CardUI.tscn")

func clear():
	for child in card_container.get_children():
		child.queue_free()
	card_uis.clear()

func play_draw_animation(hand: Array[String]):
	var old_ids := {}
	for card in card_uis:
		if is_instance_valid(card) and card.card_data:
			old_ids[card.card_data.id] = true

	var new_ids: Array[String] = []
	for cid in hand:
		if cid not in old_ids:
			new_ids.append(cid)

	if new_ids.size() == 1:
		var data = CardDatabase.get_card(new_ids[0])
		if data:
			_fly_in_card(data, hand)
			return

	set_hand(hand)

func _fly_in_card(data: CardData, hand: Array[String]):
	var card = card_scene.instantiate()
	card.scale = Vector2.ONE
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.z_index = 100
	add_child(card)
	card.setup(data)
	card.pivot_offset = card.size * 0.5

	card.position = Vector2(-card.size.x, card_container.size.y * 0.5)
	var end_x = card_container.size.x * 0.5

	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position:x", end_x, 0.4)
	tw.tween_property(card, "modulate:a", 0.0, 0.15).set_delay(0.3)
	tw.finished.connect(func():
		card.queue_free()
		set_hand(hand)
	)

func set_hand(card_ids: Array[String]):
	clear()
	for cid in card_ids:
		var data = CardDatabase.get_card(cid)
		if data:
			_add_card(data)
	_layout_cards()

func remove_card_via_data(data: CardData) -> bool:
	for i in range(card_uis.size() - 1, -1, -1):
		if card_uis[i].card_data == data:
			var card = card_uis[i]
			card_uis.remove_at(i)
			card.queue_free()
			_justify()  # snap remaining, no tween
			return true
	return false

func _add_card(data: CardData):
	var instance = card_scene.instantiate()
	card_container.add_child(instance)
	instance.setup(data)
	instance.pivot_offset = instance.size * 0.5
	card_uis.append(instance)
	instance.scale = Vector2.ZERO
	instance.modulate.a = 0.0

func _compute(i: int, n: int) -> Dictionary:
	var t = 0.0 if n == 1 else float(i) / (n - 1) - 0.5
	var spread = min(MAX_FAN_SPREAD, (n - 1) * TARGET_GAP)
	var angle = MAX_FAN_ANGLE * (spread / MAX_FAN_SPREAD)
	var cx = card_container.size.x * 0.5
	var by = card_container.size.y * 0.5
	var y = by + abs(t) * FAN_ARC_Y - FAN_ARC_Y * 0.5
	return {
		x = cx + t * spread,
		y = y,
		r = t * angle,
		spread = spread,
		angle = angle
	}

func _justify():
	var n = card_uis.size()
	if n == 0:
		return
	for i in range(n):
		var card = card_uis[i]
		if not is_instance_valid(card):
			continue
		var p = _compute(i, n)
		card.position = Vector2(p.x, p.y)
		card.rotation = p.r

func _layout_cards():
	var n = card_uis.size()
	if n == 0:
		return
	for i in range(n):
		var card = card_uis[i]
		if not is_instance_valid(card):
			continue
		var p = _compute(i, n)
		var target_pos = Vector2(p.x, p.y)
		var target_rot = p.r

		card.position = Vector2(target_pos.x, target_pos.y + 40)

		var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.25)
		tw.tween_property(card, "modulate:a", 1.0, 0.15)
		tw.tween_property(card, "position", target_pos, 0.3)
		tw.tween_property(card, "rotation", target_rot, 0.3)
