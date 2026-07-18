class_name CardDatabase
extends Node

static var all_cards: Dictionary = {}

static func _register_cards():
	var cards = [
		_create_card("card_fireball", "火球术", CardData.CardType.ATTACK, 2,
			CardData.TargetType.ENEMY_SINGLE, "对单个敌人造成 25 点伤害",
			CardData.EffectType.DAMAGE, 25),

		_create_card("card_ice_shard", "冰晶碎片", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "对单个敌人造成 12 点伤害",
			CardData.EffectType.DAMAGE, 12),

		_create_card("card_heal", "治愈之光", CardData.CardType.HEAL, 2,
			CardData.TargetType.ALLY_SINGLE, "恢复单个友方 20 点生命值",
			CardData.EffectType.HEAL, 20),

		_create_card("card_small_heal", "小治愈", CardData.CardType.HEAL, 1,
			CardData.TargetType.ALLY_SINGLE, "恢复单个友方 10 点生命值",
			CardData.EffectType.HEAL, 10),

		_create_card("card_shield", "护盾屏障", CardData.CardType.SHIELD, 2,
			CardData.TargetType.ALLY_SINGLE, "为单个友方提供 15 点护盾",
			CardData.EffectType.SHIELD, 15),

		_create_card("card_strength", "力量强化", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "友方攻击力 +10（持续 2 回合）",
			CardData.EffectType.BUFF_ATTACK, 10, 2),

		_create_card("card_weakness", "虚弱诅咒", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "敌方攻击力 -8（持续 2 回合）",
			CardData.EffectType.DEBUFF_ATTACK, 8, 2),

		_create_card("card_slow", "迟缓术", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "敌方移动力 -2（持续 1 回合）",
			CardData.EffectType.DEBUFF_MOVE, 2, 1),

		_create_card("card_fortify", "铁壁防御", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "友方获得 +8 防御（持续 2 回合）",
			CardData.EffectType.BUFF_DEFENSE, 8, 2),

		_create_card("card_draw", "谋略", CardData.CardType.TACTICAL, 1,
			CardData.TargetType.NONE, "额外抽 1 张牌",
			CardData.EffectType.DRAW_CARD, 1),

		# === Phase 4.3 新卡牌 ===
		_create_card("card_firestorm", "烈焰风暴", CardData.CardType.ATTACK, 3,
			CardData.TargetType.ENEMY_SINGLE, "对目标及周围1格敌人造成 30 点伤害",
			CardData.EffectType.AOE_DAMAGE, 30, 1, 1),

		_create_card("card_frostbite", "冰冻术", CardData.CardType.ATTACK, 2,
			CardData.TargetType.ENEMY_SINGLE, "造成 15 点伤害并附加迟缓 2 回合",
			CardData.EffectType.DEBUFF_MOVE, 2, 2),

		_create_card("card_siphon", "法力汲取", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "造成 8 点伤害并抽 1 张牌",
			CardData.EffectType.DRAW_CARD, 1),

		_create_card("card_mass_heal", "群体治愈", CardData.CardType.HEAL, 3,
			CardData.TargetType.ALLY_SINGLE, "治疗目标及周围友方 15 点生命",
			CardData.EffectType.AOE_HEAL, 15, 1, 1),

		_create_card("card_cleanse", "净化", CardData.CardType.TACTICAL, 1,
			CardData.TargetType.ALLY_SINGLE, "移除目标所有减益效果",
			CardData.EffectType.CLEANSE, 0),

		_create_card("card_haste", "加速", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "移动力 +3（持续 2 回合）",
			CardData.EffectType.EXTRA_MOVE, 3, 2),

		_create_card("card_aim", "瞄准射击", CardData.CardType.ATTACK, 2,
			CardData.TargetType.ENEMY_SINGLE, "对单个敌人造成 35 点伤害",
			CardData.EffectType.DAMAGE, 35),

		_create_card("card_arrow_rain", "箭雨", CardData.CardType.ATTACK, 3,
			CardData.TargetType.ENEMY_SINGLE, "对目标及周围2格敌人造成 20 点伤害",
			CardData.EffectType.AOE_DAMAGE, 20, 1, 2),

		_create_card("card_mark", "标记", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "标记目标，使其受到伤害 +50%（持续 2 回合）",
			CardData.EffectType.MARK, 50, 2),

		_create_card("card_shadowstep", "暗影步", CardData.CardType.DISPLACE, 2,
			CardData.TargetType.ENEMY_SINGLE, "传送到目标相邻位置并造成 15 点伤害",
			CardData.EffectType.TELEPORT, 15),

		_create_card("card_poison_blade", "毒刃", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "造成 8 点伤害并附加中毒 3 回合",
			CardData.EffectType.DAMAGE_OVER_TIME, 6, 3),

		_create_card("card_iron_wall", "铁壁形态", CardData.CardType.BUFF, 2,
			CardData.TargetType.SELF, "获得 +15 防御（持续 3 回合）",
			CardData.EffectType.BUFF_DEFENSE, 15, 3),

		_create_card("card_heal_wave", "治疗波", CardData.CardType.HEAL, 2,
			CardData.TargetType.ALLY_SINGLE, "治疗目标及其周围友方 12 点生命",
			CardData.EffectType.AOE_HEAL, 12, 1, 1),

		_create_card("card_chain_lightning", "闪电链", CardData.CardType.ATTACK, 3,
			CardData.TargetType.ENEMY_SINGLE, "对目标造成 20 点伤害，跳跃至附近敌人递减",
			CardData.EffectType.CHAIN_DAMAGE, 20),

		_create_card("card_taunt", "嘲讽", CardData.CardType.TACTICAL, 1,
			CardData.TargetType.ENEMY_SINGLE, "嘲讽目标，使其强制攻击施法者（持续 1 回合）",
			CardData.EffectType.TAUNT, 1, 1),
	]

	for c in cards:
		all_cards[c.id] = c

static func _create_card(
	id: String,
	name: String,
	type: CardData.CardType,
	cost: int,
	target_type: CardData.TargetType,
	desc: String,
	effect_type: CardData.EffectType,
	effect_value: int,
	effect_duration: int = 1,
	effect_radius: int = 0
) -> CardData:
	var card = CardData.new()
	card.id = id
	card.card_name = name
	card.card_type = type
	card.cost = cost
	card.target_type = target_type
	card.description = desc
	card.effect_type = effect_type
	card.effect_value = effect_value
	card.effect_duration = effect_duration
	card.effect_radius = effect_radius
	return card

static func get_card(card_id: String) -> CardData:
	if all_cards.is_empty():
		_register_cards()
	return all_cards.get(card_id, null)

static func get_all_card_ids() -> Array[String]:
	if all_cards.is_empty():
		_register_cards()
	var ids: Array[String] = []
	for id in all_cards:
		ids.append(id)
	return ids
