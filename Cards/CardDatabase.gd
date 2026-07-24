class_name CardDatabase
extends Node

static var all_cards: Dictionary = {}

static func _register_cards():
	var cards = [
		# ========== 费用 0 ==========
		_create_card("card_overload", "能量过载", CardData.CardType.TACTICAL, 0,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标造成 5 点伤害，获得 2 点能量",
			CardData.EffectType.DRAW_CARD, 1),

		# ========== 费用 1 — 攻击 ==========
		_create_card("card_ice_shard", "冰晶碎片", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 8 点伤害，施加 [迟缓]，效果为移动范围 -2（持续 1 回合）",
			CardData.EffectType.DAMAGE, 8),

		_create_card("card_siphon", "法力汲取", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 6 点伤害，抽 1 张牌",
			CardData.EffectType.DRAW_CARD, 1),

		_create_card("card_poison_blade", "毒刃", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 4 点伤害，施加 [中毒]，效果为每回合受到 6 点伤害（持续 3 回合）",
			CardData.EffectType.DAMAGE_OVER_TIME, 6, 3),

		_create_card("card_reckoning", "惩戒", CardData.CardType.ATTACK, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 6×目标身上 buff 数量的伤害",
			CardData.EffectType.DAMAGE, 6),

		# ========== 费用 1 — 治疗/护盾 ==========
		_create_card("card_small_heal", "小治愈", CardData.CardType.HEAL, 1,
			CardData.TargetType.ALLY_SINGLE, "为我方单体目标恢复 10 点生命值",
			CardData.EffectType.HEAL, 10),

		_create_card("card_life_split", "生命分流", CardData.CardType.HEAL, 1,
			CardData.TargetType.ALLY_SINGLE, "为我方单体目标恢复 12 点生命值，若目标已满血则改为抽 1 张牌",
			CardData.EffectType.HEAL, 12),

		_create_card("card_regen", "再生术", CardData.CardType.HEAL, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [再生]，效果为每回合恢复 5 点生命值（持续 3 回合）",
			CardData.EffectType.HEAL_OVER_TIME, 5, 3),

		_create_card("card_shield_overload", "护盾过载", CardData.CardType.SHIELD, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 8 点护盾，若已有护盾则翻倍",
			CardData.EffectType.SHIELD, 8),

		# ========== 费用 1 — Buff/Debuff ==========
		_create_card("card_strength", "力量强化", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [攻击强化]，效果为攻击力 +8（持续 2 回合）",
			CardData.EffectType.BUFF_ATTACK, 8, 2),

		_create_card("card_fortify", "铁壁防御", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [防御]，效果为受到伤害减伤 8 点（持续 2 回合）",
			CardData.EffectType.BUFF_DEFENSE, 8, 2),

		_create_card("card_haste", "加速", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [加速]，效果为移动范围 +3（持续 2 回合）",
			CardData.EffectType.EXTRA_MOVE, 3, 2),

		_create_card("card_double_edge", "双刃剑", CardData.CardType.BUFF, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [攻击强化] 和 [易伤]，效果为攻击力 +10、受到伤害 +5（持续 2 回合）",
			CardData.EffectType.BUFF_ATTACK, 10, 2),

		_create_card("card_weakness", "虚弱诅咒", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标施加 [虚弱]，效果为攻击力 -6（持续 2 回合）",
			CardData.EffectType.DEBUFF_ATTACK, 6, 2),

		_create_card("card_slow", "迟缓术", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标施加 [迟缓]，效果为移动范围 -2（持续 1 回合）",
			CardData.EffectType.DEBUFF_MOVE, 2, 1),

		_create_card("card_mark", "标记", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标施加 [标记]，效果为受到伤害 +50%（持续 2 回合）",
			CardData.EffectType.MARK, 50, 2),

		_create_card("card_hemorrhage", "出血", CardData.CardType.DEBUFF, 1,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标施加 [中毒]，效果为每回合受到 7 点伤害（持续 3 回合）",
			CardData.EffectType.DAMAGE_OVER_TIME, 7, 3),

		# ========== 费用 1 — 战术 ==========
		_create_card("card_draw", "谋略", CardData.CardType.TACTICAL, 1,
			CardData.TargetType.NONE, "抽 1 张牌",
			CardData.EffectType.DRAW_CARD, 1),

		_create_card("card_cleanse", "净化", CardData.CardType.TACTICAL, 1,
			CardData.TargetType.ALLY_SINGLE, "移除我方单体目标身上的所有减益效果",
			CardData.EffectType.CLEANSE, 0),

		_create_card("card_taunt", "嘲讽", CardData.CardType.TACTICAL, 1,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [嘲讽]，效果为强制敌方只能攻击该角色（持续 1 回合）",
			CardData.EffectType.TAUNT, 1, 1),

		# ========== 费用 2 — 攻击 ==========
		_create_card("card_fireball", "火球术", CardData.CardType.ATTACK, 2,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 20 点伤害，施加 [灼烧]，效果为每回合受到 5 点伤害（持续 2 回合）",
			CardData.EffectType.DAMAGE, 20),

		_create_card("card_aim", "瞄准射击", CardData.CardType.ATTACK, 2,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 28 点伤害",
			CardData.EffectType.DAMAGE, 28),

		_create_card("card_frostbite", "冰冻术", CardData.CardType.ATTACK, 2,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 12 点伤害，施加 [迟缓]，效果为移动范围 -2（持续 2 回合）",
			CardData.EffectType.DEBUFF_MOVE, 2, 2),

		_create_card("card_shadowstep", "暗影步", CardData.CardType.DISPLACE, 2,
			CardData.TargetType.ALLY_SINGLE, "使我方单体目标瞬移至距离最远的敌方目标旁，对其造成 12 点伤害",
			CardData.EffectType.TELEPORT, 12),

		# ========== 费用 2 — 治疗/护盾 ==========
		_create_card("card_heal", "治愈之光", CardData.CardType.HEAL, 2,
			CardData.TargetType.ALLY_SINGLE, "为我方单体目标恢复 20 点生命值",
			CardData.EffectType.HEAL, 20),

		_create_card("card_heal_wave", "治疗波", CardData.CardType.HEAL, 2,
			CardData.TargetType.NONE, "为我方全体目标恢复 10 点生命值",
			CardData.EffectType.AOE_HEAL, 10),

		_create_card("card_shield", "护盾屏障", CardData.CardType.SHIELD, 2,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 16 点护盾",
			CardData.EffectType.SHIELD, 16),

		_create_card("card_ice_shield", "冰盾", CardData.CardType.SHIELD, 2,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 18 点护盾",
			CardData.EffectType.SHIELD, 18),

		# ========== 费用 2 — Buff/Debuff ==========
		_create_card("card_iron_wall", "铁壁形态", CardData.CardType.BUFF, 2,
			CardData.TargetType.ALLY_SINGLE, "对我方单体目标施加 [防御]，效果为受到伤害减伤 12 点（持续 3 回合）",
			CardData.EffectType.BUFF_DEFENSE, 12, 3),

		_create_card("card_disarm", "时停", CardData.CardType.DEBUFF, 2,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标施加 [虚弱]，效果为攻击力 -8（持续 3 回合）",
			CardData.EffectType.DEBUFF_ATTACK, 8, 3),

		# ========== 费用 2 — 战术 ==========
		_create_card("card_echo", "回响", CardData.CardType.TACTICAL, 2,
			CardData.TargetType.NONE, "抽 2 张牌",
			CardData.EffectType.DRAW_CARD, 2),

		# ========== 费用 3 ==========
		_create_card("card_firestorm", "烈焰风暴", CardData.CardType.ATTACK, 3,
			CardData.TargetType.NONE, "对敌方全体目标造成 24 点伤害",
			CardData.EffectType.AOE_DAMAGE, 24),

		_create_card("card_arrow_rain", "箭雨", CardData.CardType.ATTACK, 3,
			CardData.TargetType.NONE, "对敌方全体目标造成 16 点伤害",
			CardData.EffectType.AOE_DAMAGE, 16),

		_create_card("card_chain_lightning", "闪电链", CardData.CardType.ATTACK, 3,
			CardData.TargetType.ENEMY_SINGLE, "对敌方单体目标造成 20 点伤害，周围 1 格内的其他敌方目标额外受到 10 点伤害，周围 2 格内的其他敌方目标额外受到 5 点伤害",
			CardData.EffectType.CHAIN_DAMAGE, 20),

		_create_card("card_mass_heal", "群体治愈", CardData.CardType.HEAL, 3,
			CardData.TargetType.NONE, "为我方全体目标恢复 14 点生命值",
			CardData.EffectType.AOE_HEAL, 14),
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
