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
	if not "buffs" in target:
		target.set("buffs", {})
	target.buffs[buff_key] = { "value": value, "remaining": duration }
	if target.has_method("rpc"):
		target.rpc("_sync_buffs", target.buffs.duplicate())
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
	if "buffs" in target:
		target.buffs.clear()
		if target.has_method("rpc"):
			target.rpc("_sync_buffs", {})
	return true
