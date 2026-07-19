extends Control

var card_uis: Array[CardUI] = []

const MAX_FAN_ANGLE: float = deg_to_rad(12.0)
const MAX_FAN_SPREAD: float = 320.0
const FAN_ARC_Y: float = 50.0
const TARGET_GAP: float = 120.0

@onready var card_container: Control = $CardContainer
@onready var card_scene: PackedScene = preload("res://UI/CardUI.tscn")

func clear():
	for child in card_container.get_children():
		child.queue_free()
	card_uis.clear()

func play_draw_animation(hand: Array[String]):
	set_hand(hand)

func set_hand(card_ids: Array[String]):
	clear()
	for cid in card_ids:
		var data = CardDatabase.get_card(cid)
		if data:
			_add_card(data)
	if card_uis.is_empty() and not card_ids.is_empty():
		push_error("HandPanel: set_hand produced 0 cards from " + str(card_ids.size()) + " IDs")
	_layout_cards()

func remove_card_via_data(data: CardData) -> bool:
	for i in range(card_uis.size() - 1, -1, -1):
		if card_uis[i].card_data == data:
			var card = card_uis[i]
			card_uis.remove_at(i)
			card.queue_free()
			# give remaining cards entrance animation
			for c in card_uis:
				c.set_meta("_entrance", true)
			_layout_cards()
			return true
	return false

func _add_card(data: CardData):
	var instance = card_scene.instantiate()
	card_container.add_child(instance)
	instance.setup(data)
	instance.pivot_offset = instance.size * 0.5
	card_uis.append(instance)
	instance.set_meta("_entrance", true)

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

func _z(i: int, n: int) -> int:
	var center = float(n - 1) * 0.5
	return int(n - abs(float(i) - center))

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
		card.z_index = _z(i, n)

func _layout_cards():
	var n = card_uis.size()
	if n == 0:
		return
	var effective_spread = min(MAX_FAN_SPREAD, (n - 1) * TARGET_GAP)
	var effective_angle = MAX_FAN_ANGLE * (effective_spread / MAX_FAN_SPREAD)
	var center_x = card_container.size.x * 0.5
	var base_y = card_container.size.y * 0.5

	for i in range(n):
		var card = card_uis[i]
		if not is_instance_valid(card):
			continue

		# kill any stale tween on this card
		if card.has_meta("_tw"):
			var t: Tween = card.get_meta("_tw")
			if is_instance_valid(t):
				t.kill()

		var p = _compute(i, n)
		var target_pos = Vector2(p.x, p.y)
		var target_rot = p.r

		card.z_index = _z(i, n)

		if card.has_meta("_entrance"):
			card.remove_meta("_entrance")
			card.scale = Vector2.ONE
			card.modulate.a = 1.0

			var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			card.set_meta("_tw", tw)
			tw.tween_property(card, "position", target_pos, 0.3)
			tw.tween_property(card, "rotation", target_rot, 0.3)
		else:
			# existing card: tween from current to new fan position
			var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			card.set_meta("_tw", tw)
			tw.tween_property(card, "position", target_pos, 0.3)
			tw.tween_property(card, "rotation", target_rot, 0.3)
