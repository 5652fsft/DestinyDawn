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
			return _execute_teleport(card, target, main)
		CardData.EffectType.DRAW_CARD:
			return _execute_draw_card(card, caster, main)
		CardData.EffectType.CLEANSE:
			return _execute_cleanse(target)
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
		target.rpc("_play_vfx", Color(0.2, 1.0, 0.2), 0.25)
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
		target.rpc("_play_vfx", Color(0.3, 0.5, 1.0), 0.3)
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

static func _execute_teleport(card: CardData, target: Node, main: Node) -> bool:
	if not target or not main or not target.has_method("get_current_cell"):
		return false
	# 简化：位移效果由外部处理，这里标记成功
	return true

static func _execute_draw_card(card: CardData, caster: Node, main: Node) -> bool:
	if not main or not main.has_method("draw_extra_card"):
		return false
	main.draw_extra_card(caster)
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
