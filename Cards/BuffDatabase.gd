class_name BuffDatabase

static func get_buff_data(buff_id: String) -> BuffData:
	return _all_buffs().get(buff_id, null)

static func _all_buffs() -> Dictionary:
	var out: Dictionary = {}
	var b: BuffData

	b = BuffData.new()
	b.id = "attack_buff"; b.name = "力量强化"; b.type = BuffData.BuffType.ATTACK_BUFF
	b.category = BuffData.Category.MAGIC; b.is_harmful = false; b.max_stacks = 3
	out["attack_buff"] = b

	b = BuffData.new()
	b.id = "attack_debuff"; b.name = "虚弱"; b.type = BuffData.BuffType.ATTACK_DEBUFF
	b.category = BuffData.Category.MAGIC; b.is_harmful = true; b.max_stacks = 3
	out["attack_debuff"] = b

	b = BuffData.new()
	b.id = "defense_buff"; b.name = "伤害减免"; b.type = BuffData.BuffType.DEFENSE_BUFF
	b.category = BuffData.Category.PHYSICAL; b.is_harmful = false; b.max_stacks = 2
	out["defense_buff"] = b

	b = BuffData.new()
	b.id = "move_debuff"; b.name = "迟缓"; b.type = BuffData.BuffType.MOVE_DEBUFF
	b.category = BuffData.Category.MAGIC; b.is_harmful = true; b.max_stacks = 2
	out["move_debuff"] = b

	b = BuffData.new()
	b.id = "poison"; b.name = "中毒"; b.type = BuffData.BuffType.DAMAGE_OVER_TIME
	b.category = BuffData.Category.PHYSICAL; b.is_harmful = true; b.max_stacks = 5; b.has_tick = true
	out["poison"] = b

	b = BuffData.new()
	b.id = "burn"; b.name = "灼烧"; b.type = BuffData.BuffType.DAMAGE_OVER_TIME
	b.category = BuffData.Category.MAGIC; b.is_harmful = true; b.max_stacks = 3; b.has_tick = true
	out["burn"] = b

	b = BuffData.new()
	b.id = "regen"; b.name = "再生"; b.type = BuffData.BuffType.HEAL_OVER_TIME
	b.category = BuffData.Category.MAGIC; b.is_harmful = false; b.max_stacks = 3; b.has_tick = true
	out["regen"] = b

	b = BuffData.new()
	b.id = "mark"; b.name = "标记"; b.type = BuffData.BuffType.MARK
	b.category = BuffData.Category.SPECIAL; b.is_harmful = true; b.max_stacks = 1
	out["mark"] = b

	b = BuffData.new()
	b.id = "bloodthirst"; b.name = "嗜血成性"; b.type = BuffData.BuffType.ATTACK_BUFF
	b.category = BuffData.Category.SPECIAL; b.is_harmful = false; b.max_stacks = 3
	out["bloodthirst"] = b

	b = BuffData.new()
	b.id = "magic_flow"; b.name = "魔力充盈"; b.type = BuffData.BuffType.ATTACK_BUFF
	b.category = BuffData.Category.SPECIAL; b.is_harmful = false; b.max_stacks = 3
	out["magic_flow"] = b

	b = BuffData.new()
	b.id = "taunt"; b.name = "嘲讽"; b.type = BuffData.BuffType.ATTACK_DEBUFF
	b.category = BuffData.Category.SPECIAL; b.is_harmful = true; b.max_stacks = 1
	out["taunt"] = b

	b = BuffData.new()
	b.id = "legacy"; b.name = "传承"; b.type = BuffData.BuffType.ATTACK_BUFF
	b.category = BuffData.Category.SPECIAL; b.is_harmful = false; b.max_stacks = 3
	out["legacy"] = b

	b = BuffData.new()
	b.id = "ascend"; b.name = "攀升"; b.type = BuffData.BuffType.DEFENSE_BUFF
	b.category = BuffData.Category.SPECIAL; b.is_harmful = false; b.max_stacks = 2
	out["ascend"] = b

	b = BuffData.new()
	b.id = "hot_burn"; b.name = "高温烫嘴"; b.type = BuffData.BuffType.MARK
	b.category = BuffData.Category.SPECIAL; b.is_harmful = true; b.max_stacks = 1
	out["hot_burn"] = b

	b = BuffData.new()
	b.id = "soften"; b.name = "松软"; b.type = BuffData.BuffType.MARK
	b.category = BuffData.Category.SPECIAL; b.is_harmful = true; b.max_stacks = 1
	out["soften"] = b

	b = BuffData.new()
	b.id = "rope"; b.name = "拧绳"; b.type = BuffData.BuffType.MARK
	b.category = BuffData.Category.SPECIAL; b.is_harmful = false; b.max_stacks = 99
	out["rope"] = b

	b = BuffData.new()
	b.id = "solo_leveling"; b.name = "我独自升级"; b.type = BuffData.BuffType.ATTACK_BUFF
	b.category = BuffData.Category.SPECIAL; b.is_harmful = false; b.max_stacks = 1
	out["solo_leveling"] = b

	return out
