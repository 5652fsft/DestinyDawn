class_name CardEffect
extends Node

static func execute(card: CardData, caster: Node, target: Node, main: Node) -> bool:
	if not card or not caster or not main:
		return false

	match card.effect_type:
		CardData.EffectType.DAMAGE:
			return _execute_damage(card, target, main)
		CardData.EffectType.HEAL:
			return _execute_heal(card, target)
		CardData.EffectType.SHIELD:
			return _execute_shield(card, target)
		CardData.EffectType.BUFF_ATTACK:
			return _execute_buff_attack(card, target)
		CardData.EffectType.BUFF_DEFENSE:
			return _execute_buff_defense(card, target)
		CardData.EffectType.DEBUFF_ATTACK:
			return _execute_debuff_attack(card, target)
		CardData.EffectType.DEBUFF_MOVE:
			return _execute_debuff_move(card, target)
		CardData.EffectType.TELEPORT:
			return _execute_teleport(card, target, main, caster)
		CardData.EffectType.SWAP:
			return _execute_swap(card, target, main, caster)
		CardData.EffectType.EXTRA_MOVE:
			return _apply_temp_buff(target, "extra_move", card.effect_value, card.effect_duration)
		CardData.EffectType.DRAW_CARD:
			return _execute_draw_card(card, caster, main)
		CardData.EffectType.CLEANSE:
			return _execute_cleanse(target)
		CardData.EffectType.AOE_DAMAGE:
			return _execute_aoe_damage(card, target, main, caster)
		CardData.EffectType.AOE_HEAL:
			return _execute_aoe_heal(card, target, main)
		CardData.EffectType.CHAIN_DAMAGE:
			return _execute_chain_damage(card, target, main)
		CardData.EffectType.DAMAGE_OVER_TIME:
			return _apply_temp_buff(target, "poison", card.effect_value, card.effect_duration)
		CardData.EffectType.HEAL_OVER_TIME:
			return _apply_temp_buff(target, "regen", card.effect_value, card.effect_duration)
		CardData.EffectType.LINEAR_AOE:
			return _execute_linear_aoe(card, target, main, caster)
		CardData.EffectType.MARK:
			return _apply_temp_buff(target, "mark", card.effect_value, card.effect_duration)
		CardData.EffectType.TAUNT:
			return _apply_temp_buff(target, "taunt", card.effect_value, card.effect_duration)
		_:
			push_warning("未知卡牌效果类型: ", card.effect_type)
			return false

static func _execute_damage(card: CardData, target: Node, main: Node) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	if target.has_method("rpc"):
		target.rpc("take_damage", card.effect_value)
	else:
		target.take_damage(card.effect_value)
	return true

static func _execute_heal(card: CardData, target: Node) -> bool:
	if not target or not "hp" in target or not "max_hp" in target:
		return false
	var heal_amount = min(card.effect_value, target.max_hp - target.hp)
	if heal_amount <= 0:
		return false
	if target.has_method("rpc"):
		target.rpc("take_damage", -heal_amount)
		target.rpc("_play_vfx_preset", "heal")
	else:
		target.hp = min(target.max_hp, target.hp + heal_amount)
	return true

static func _execute_shield(card: CardData, target: Node) -> bool:
	if not target:
		return false
	if not "shield" in target:
		target.set("shield", 0)
	target.shield = target.shield + card.effect_value
	if target.has_method("rpc"):
		target.rpc("_sync_shield", target.shield)
		target.rpc("_play_vfx_preset", "shield")
	return true

static func _execute_buff_attack(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "attack_buff", card.effect_value, card.effect_duration)

static func _execute_buff_defense(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "defense_buff", card.effect_value, card.effect_duration)

static func _execute_debuff_attack(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "attack_debuff", -card.effect_value, card.effect_duration)

static func _execute_debuff_move(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "move_debuff", -card.effect_value, card.effect_duration)

static func _apply_temp_buff(target: Node, buff_key: String, value: int, duration: int) -> bool:
	if not target:
		return false
	var main = target.get_tree().current_scene
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("apply_buff"):
		return bm.apply_buff(target, buff_key, value, duration)
	# fallback: direct
	if not "buffs" in target:
		target.set("buffs", {})
	var entry = { "value": value, "remaining": duration }
	if not target.buffs.has(buff_key):
		target.buffs[buff_key] = []
	target.buffs[buff_key].append(entry)
	if target.has_method("rpc"):
		target.rpc("_sync_buffs", target.buffs.duplicate())
		var vfx_color = Color(1.0, 0.9, 0.2) if value > 0 else Color(0.6, 0.2, 0.8)
		target.rpc("_play_vfx", vfx_color, 0.25)
	return true

static func _execute_teleport(card: CardData, target: Node, main: Node, caster: Node) -> bool:
	if not target or not caster or not target.has_method("get_current_cell"):
		return false
	var target_cell = target.get_current_cell()
	var neighbors = [
		Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1),
		Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)
	]
	var pick = target_cell + neighbors[randi() % neighbors.size()]
	if caster.has_method("get_grid_layer"):
		var gl = caster.get_grid_layer()
		if gl:
			var world_pos = gl.to_global(gl.map_to_local(pick))
			caster.global_position = world_pos
			caster.target_world = world_pos
	caster.rpc("_play_vfx_preset", "entrance")
	if card.effect_value > 0 and target.has_method("take_damage"):
		target.rpc("take_damage", card.effect_value)
		target.rpc("_play_vfx_preset", "hit")
	return true

static func _execute_draw_card(card: CardData, caster: Node, main: Node) -> bool:
	if not main or not main.has_method("draw_extra_card"):
		return false
	main.draw_extra_card(caster)
	return true

static func _get_characters_in_range(main: Node, center: Node, radius: int) -> Array:
	var chars: Array = []
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == center:
			continue
		if center.global_position.distance_to(c.global_position) <= radius * 130.0:
			chars.append(c)
	return chars

static func _execute_aoe_damage(card: CardData, target: Node, main: Node, caster: Node) -> bool:
	if not target or not main:
		return false
	var targets = _get_characters_in_range(main, target, card.effect_radius)
	for t in targets:
		if t.has_method("take_damage"):
			if t.has_method("rpc"):
				t.rpc("take_damage", card.effect_value)
			else:
				t.take_damage(card.effect_value)
	if caster and caster.has_method("rpc"):
		caster.rpc("_play_vfx_preset", "explosion")
	return true

static func _execute_aoe_heal(card: CardData, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	var targets = _get_characters_in_range(main, target, card.effect_radius)
	for t in targets:
		if t.has_method("take_damage"):
			if t.has_method("rpc"):
				t.rpc("take_damage", -card.effect_value)
			else:
				t.take_damage(-card.effect_value)
	return true

static func _execute_chain_damage(card: CardData, primary: Node, main: Node) -> bool:
	if not primary or not main:
		return false
	var hit: Array = [primary]
	var remaining = 3
	var current = primary
	while remaining > 0:
		var nearest = null
		var nearest_dist = 99999.0
		for c in main.get_tree().get_nodes_in_group("characters"):
			if c in hit:
				continue
			var d = current.global_position.distance_to(c.global_position)
			if d < nearest_dist and d <= 200.0:
				nearest = c
				nearest_dist = d
		if not nearest:
			break
		var dmg = card.effect_value - (3 - remaining) * 5
		if nearest.has_method("rpc"):
			nearest.rpc("take_damage", max(1, dmg))
		else:
			nearest.take_damage(max(1, dmg))
		hit.append(nearest)
		current = nearest
		remaining -= 1
	return hit.size() > 1

static func _execute_linear_aoe(card: CardData, target: Node, main: Node, caster: Node) -> bool:
	if not target or not main or not caster:
		return false
	var dir = (target.global_position - caster.global_position).normalized()
	var max_dist = card.effect_value  # use effect_value as range
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == caster:
			continue
		var to = c.global_position - caster.global_position
		var dot = to.dot(dir)
		if dot > 0 and dot <= max_dist * 130.0:
			var lateral = to.length() - dot
			if lateral < 80.0:
				if c.has_method("rpc"):
					c.rpc("take_damage", card.effect_value)
				else:
					c.take_damage(card.effect_value)
	return true

static func _execute_swap(card: CardData, target: Node, main: Node, caster: Node) -> bool:
	if not caster or not target or not caster.has_method("get_current_cell"):
		return false
	var caster_pos = caster.global_position
	var target_pos = target.global_position
	caster.global_position = target_pos
	caster.target_world = target_pos
	target.global_position = caster_pos
	if target.has_method("move_toward_target"):
		target.target_world = caster_pos
	caster.rpc("_play_vfx_preset", "entrance")
	target.rpc("_play_vfx_preset", "entrance")
	return true

static func _execute_cleanse(target: Node) -> bool:
	if not target:
		return false
	var main = target.get_tree().current_scene
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("cleanse"):
		return bm.cleanse(target, "all") > 0
	if "buffs" in target:
		target.buffs.clear()
		if target.has_method("rpc"):
			target.rpc("_sync_buffs", {})
	return true
