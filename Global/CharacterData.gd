class_name CharacterData

const DATA = {
	"bronya":    {"name":"布洛妮娅", "hp":68,  "move":5, "atk":15, "range":3,
		"skill":"护卫指令", "skill_desc":"为友方单体目标提供30点护盾", "skill_cd":3,
		"skill_value":30,
		"passive":"铁壁", "passive_desc":"受到伤害-20%，当生命值低于50%时受到伤害-35%",
		"passive_reduction":0.2, "passive_reduction_low":0.35, "passive_low_hp":0.5},
	"seele":     {"name":"希儿",    "hp":65,  "move":6, "atk":18, "range":4,
		"skill":"相位突进", "skill_desc":"瞬移至10格范围内选定的敌方单体目标旁，并为目标造成120%攻击力的伤害", "skill_cd":3,
		"skill_multiplier":1.2,
		"passive":"暗影突袭", "passive_desc":"攻击满血敌人时伤害+50%",
		"passive_full_hp_bonus":0.5},
	"elaina":    {"name":"伊蕾娜",  "hp":60,  "move":5, "atk":20, "range":5,
		"skill":"星尘爆裂", "skill_desc":"对6格范围内敌方单体目标及周围2格敌方目标造成125%攻击力的伤害", "skill_cd":4,
		"skill_multiplier":1.25, "skill_radius":2,
		"passive":"魔力共鸣", "passive_desc":"使用攻击/减益卡牌时，获得一层[魔力充盈]，效果为攻击力+15%，持续2回合，最多可叠加3层",
		"passive_magic_value":15, "passive_magic_duration":2},
	"firefly":   {"name":"流萤",    "hp":85,  "move":5, "atk":14, "range":1,
		"skill":"烈焰冲锋", "skill_desc":"对6格范围内敌方单体目标造成180%攻击力的伤害并施加[灼烧]，效果为每回合受到5点伤害，持续2回合", "skill_cd":3,
		"skill_multiplier":1.8, "skill_buff_id":"burn", "skill_buff_value":5, "skill_buff_duration":2,
		"passive":"燃烧装甲", "passive_desc":"每回合首次受击时，对攻击者施加[灼烧]，效果为每回合受到5点伤害，持续2回合",
		"passive_buff_value":5, "passive_buff_duration":2},
	"silverwolf":{"name":"银狼",    "hp":65,  "move":5, "atk":16, "range":2,
		"skill":"系统入侵", "skill_desc":"对敌方单体目标施加[虚弱]，效果为攻击力-8，持续3回合；并施加[迟缓]，效果为移动范围-2，持续3回合", "skill_cd":4,
		"skill_attack_value":8, "skill_move_value":2, "skill_duration":3,
		"passive":"数据篡改", "passive_desc":"攻击时对目标附加随机减益",
		"passive_attack_value":5, "passive_move_value":2},
	"hamster":   {"name":"芝士仓鼠","hp":48,  "move":6, "atk":24, "range":3,
		"skill":"动作如潮", "skill_desc":"立即获得1次额外行动，该技能不消耗行动次数", "skill_cd":3,
		"skill_extra_actions":1,
		"passive":"钢铁直架", "passive_desc":"消灭敌方后获得1次额外行动，获得一层[嗜血成性]，效果为攻击力+50%，持续两回合，最多可叠加3层",
		"passive_buff_value":50, "passive_buff_duration":2},
	"karrigan":    {"name":"karrigan", "hp":65,  "move":9, "atk":10, "range":6,
		"skill":"狂野·纵横烟中", "skill_desc":"在目标地格及其周围三格展开烟雾，持续两回合。友方角色移动后若停留在烟雾范围内，则该次移动不消耗移动次数", "skill_cd":3,
		"skill_radius":3, "skill_duration":2,
		"passive":"倒霉·混烟致残", "passive_desc":"karrigan死亡后，剩余友方下回合获得一次额外行动和[传承]，效果为攻击力+50%",
		"passive_legacy_value":50, "passive_legacy_duration":2},
	"zephyr":      {"name":"Zephyr", "hp":85,  "move":5, "atk":8, "range":3,
		"skill":"引煞赴烬", "skill_desc":"降低当前20%血量，获得一层[攀升]，效果为受到伤害-10%，持续两回合，最多两层。该技能不消耗行动次数", "skill_cd":0,
		"skill_self_damage_pct":0.2, "skill_buff_value":10, "skill_buff_duration":2,
		"passive":"血煞逆锋", "passive_desc":"根据已损失血量增加攻击力，数值为已损失血量的60%",
		"passive_damage_pct":0.6},
	"M1DorG":    {"name":"M1DorG", "hp":72,  "move":6, "atk":11, "range":1,
		"skill":"我玩蔚蓝去了", "skill_desc":"下一回合无法移动与行动，在再下一个回合回归，回归时恢复全体友方生命值至上限", "skill_cd":4,
		"skill_away_turns":2,
		"passive":"Intel工程师", "passive_desc":"对敌方目标释放攻击后，若没有造成击杀，移除我方随机1名角色的随机1个负面效果，并使其恢复10点生命值",
		"passive_heal":10},
	"Richardovo":{"name":"Richardovo", "hp":70,  "move":7, "atk":14, "range":1,
		"skill":"突破", "skill_desc":"消除自身所有效果，每消除1个效果获得1次额外行动。该技能不消耗行动次数", "skill_cd":2,
		"passive":"闭麦", "passive_desc":"回合开始时若自身无增益效果，则获得[我独自升级]，效果为伤害+20%",
		"passive_solo_value":20},
	"anpan":   {"name":"あんパン", "hp":65,  "move":5, "atk":13, "range":3, "skill_energy":4,
		"skill":"极速高温烘焙", "skill_desc":"消耗4点能量，立即抽取卡牌至上限，并为自身恢复能量至上限。获得[松软]，效果为受到伤害+20%，持续3回合", "skill_cd":3,
		"skill_buff_value":20, "skill_buff_duration":3,
		"passive":"面包大家族", "passive_desc":"每使用2张卡牌摸取1张卡牌，不超过手牌数量上限，并恢复1点能量。攻击敌方目标后，为目标施加[高温烫嘴]，持续两回合，效果为受到伤害+5%",
		"passive_hot_burn_value":5, "passive_hot_burn_duration":2},
	"anjing":  {"name":"Anjing", "hp":63,  "move":5, "atk":10, "range":3, "skill_energy":2,
		"skill":"不打气不气", "skill_desc":"消耗2点能量（此次能量消耗不触发天赋[贪玩雀神]），移除所有[牌运]，抽取等同于移除层数的增益效果牌，对敌方群体造成50%攻击力+当前手牌数量×3点伤害", "skill_cd":2,
		"skill_multiplier":0.5, "skill_hand_damage":3,
		"passive":"贪玩雀神", "passive_desc":"每消耗1点能量即获得1层[牌运]，效果为攻击力+2，持续2回合，最多可叠加4层",
		"passive_luck_value":2, "passive_luck_duration":2},
}

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, {})

static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in DATA:
		ids.append(k)
	return ids

# 角色 ID → 图片文件名首字母大写映射
static func get_sprite_id(id: String) -> String:
	match id:
		"silverwolf": return "SilverWolf"
		"anpan": return "Anpan"
		_: return id[0].to_upper() + id.substr(1)
