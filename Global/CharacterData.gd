class_name CharacterData

const DATA = {
	"bronya":    {"name":"布洛妮娅", "hp":68,  "move":5, "atk":15, "range":1,
		"skill":"护卫指令", "skill_desc":"为友方单体提供30点护盾", "skill_cd":3,
		"passive":"铁壁", "passive_desc":"受到伤害-20%，当生命值低于50%时受到伤害-35%"},
	"seele":     {"name":"希儿",    "hp":65,  "move":6, "atk":18, "range":1,
		"skill":"相位突进", "skill_desc":"瞬移至10格范围内选定的敌方单体目标旁，并为目标造成120%攻击力的伤害", "skill_cd":3,
		"passive":"暗影突袭", "passive_desc":"攻击满血敌人时伤害+50%"},
	"elaina":    {"name":"伊蕾娜",  "hp":60,  "move":5, "atk":20, "range":3,
		"skill":"星尘爆裂", "skill_desc":"为6格范围内目标及周围1格敌人造成125%攻击力的伤害", "skill_cd":4,
		"passive":"魔力共鸣", "passive_desc":"使用攻击/减益卡牌时，获得一层[魔力充盈]，效果为攻击力+15%，持续2回合，最多可叠加3层"},
	"firefly":   {"name":"流萤",    "hp":85,  "move":5, "atk":14, "range":1,
		"skill":"烈焰冲锋", "skill_desc":"为6格范围内目标造成180%攻击力的伤害并附加灼烧2回合", "skill_cd":3,
		"passive":"燃烧装甲", "passive_desc":"每回合首次受击时有50%概率反击灼烧"},
	"silverwolf":{"name":"银狼",    "hp":65,  "move":5, "atk":16, "range":2,
		"skill":"系统入侵", "skill_desc":"目标虚弱+迟缓各3回合", "skill_cd":4,
		"passive":"数据篡改", "passive_desc":"攻击时有50%概率对目标附加随机减益"},
	"hamster":   {"name":"芝士仓鼠","hp":48,  "move":6, "atk":24, "range":3,
		"skill":"动作如潮", "skill_desc":"立即获得1次额外行动，该技能不消耗行动次数", "skill_cd":3,
		"passive":"钢铁直架", "passive_desc":"消灭敌方后获得1次额外行动，获得一层[嗜血成性]，效果为攻击力+50%，持续两回合，最多可叠加3层"},
	"karrigan":    {"name":"karrigan", "hp":65,  "move":9, "atk":10, "range":6,
		"skill":"狂野·纵横烟中", "skill_desc":"在目标地格及其周围三格展开烟雾，持续两回合。友方角色移动后若停留在烟雾范围内，则该次移动不消耗移动次数", "skill_cd":3,
		"passive":"倒霉·混烟致残", "passive_desc":"karrigan在场时，友方全体获得[拧绳]，效果为受到攻击时karrigan分摊30%伤害。karrigan死亡后移除友方所有[拧绳]，剩余友方下回合获得一次额外行动和[传承]，效果为攻击力+50%"},
	"zephyr":      {"name":"Zephyr", "hp":85,  "move":5, "atk":8, "range":3,
		"skill":"引煞赴烬", "skill_desc":"降低当前20%血量，获得一层[攀升]，效果为受到伤害-10%，持续两回合，最多两层。不消耗行动次数", "skill_cd":0,
		"passive":"血煞逆锋", "passive_desc":"根据已损失血量增加攻击力，数值为已损失血量的60%"},
	"M1DorG":    {"name":"M1DorG", "hp":72,  "move":6, "atk":11, "range":1,
		"skill":"我玩蔚蓝去了", "skill_desc":"下一回合无法移动与行动，在再下一个回合回归，回归时恢复全体友方生命值至上限", "skill_cd":4,
		"passive":"Intel工程师", "passive_desc":"对敌方目标释放攻击后，若没有造成击杀，移除我方随机1名角色的随机1个负面效果，并使其恢复10点生命值"},
	"Richardovo":{"name":"Richardovo", "hp":70,  "move":7, "atk":14, "range":1,
		"skill":"突破", "skill_desc":"消除自身所有效果，每消除1个效果获得1次额外行动", "skill_cd":2,
		"passive":"闭麦", "passive_desc":"回合开始时若自身无增益效果，则获得[我独自升级]，效果为伤害+20%"},
	"anpan":   {"name":"あんパン", "hp":65,  "move":5, "atk":13, "range":3, "skill_energy":4,
		"skill":"极速高温烘焙", "skill_desc":"消耗4点能量，立即抽取卡牌至上限，并为自身恢复能量至上限。获得[松软]，效果为受到伤害+20%，持续3回合", "skill_cd":3,
		"passive":"面包大家族", "passive_desc":"每使用2张卡牌摸取1张卡牌，不超过手牌数量上限，并恢复1点能量。攻击敌方目标后，为目标施加[高温烫嘴]，持续两回合，效果为受到伤害+5%"},
	"anjing":  {"name":"Anjing", "hp":63,  "move":5, "atk":10, "range":3, "skill_energy":2,
		"skill":"不打气不气", "skill_desc":"消耗2点能量（此次能量消耗不触发天赋[贪玩雀神]），移除所有[牌运]，抽取等同于移除层数的增益效果牌，对敌方群体造成50%攻击力+当前手牌数量×3点伤害", "skill_cd":2,
		"passive":"贪玩雀神", "passive_desc":"每消耗1点能量即获得1层[牌运]，效果为攻击力+2，持续2回合，最多可叠加4层"},
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
