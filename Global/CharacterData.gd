const DATA = {
	"bronya":    {"name":"布洛妮娅", "hp":68,  "move":5, "atk":15, "range":1,
		"skill":"护卫指令", "skill_desc":"为友方单体提供 30 点护盾", "skill_cd":3,
		"passive":"铁壁", "passive_desc":"受到伤害 -20%，当生命值 <50% 时受到伤害 -35%）"},
	"seele":     {"name":"希儿",    "hp":55,  "move":6, "atk":18, "range":1,
		"skill":"相位突进", "skill_desc":"瞬移至目标旁并发动一次 1.2 倍强化攻击", "skill_cd":3,
		"passive":"暗影突袭", "passive_desc":"攻击满血敌人时伤害 +50%"},
	"elaina":    {"name":"伊蕾娜",  "hp":50,  "move":5, "atk":20, "range":3,
		"skill":"星尘爆裂", "skill_desc":"对目标及周围 1 格敌人造成 35 点伤害", "skill_cd":4,
		"passive":"魔力共鸣", "passive_desc":"连续使用攻击卡或减益卡时，每张卡牌伤害 +15%，最多可叠加 3 层"},
	"firefly":   {"name":"流萤",    "hp":76,  "move":5, "atk":14, "range":1,
		"skill":"烈焰冲锋", "skill_desc":"造成 25 点伤害并附加灼烧 2 回合", "skill_cd":3,
		"passive":"燃烧装甲", "passive_desc":"每回合首次受击时有 50% 概率反击灼烧"},
	"silverwolf":{"name":"银狼",    "hp":55,  "move":5, "atk":16, "range":2,
		"skill":"系统入侵", "skill_desc":"目标虚弱 + 迟缓各 3 回合", "skill_cd":4,
		"passive":"数据篡改", "passive_desc":"攻击时有 50% 概率对目标附加随机减益"},
	"hamster":   {"name":"芝士仓鼠","hp":38,  "move":6, "atk":26, "range":4,
		"skill":"动作如潮", "skill_desc":"立即获得 1 次额外行动", "skill_cd":3,
		"passive":"钢铁直架", "passive_desc":"消灭敌方后获得 1 次额外行动，获得一层 [嗜血成性]，效果为攻击力 +50%，持续两回合，最多可叠加 3 层"},
}

static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in DATA:
		ids.append(k)
	return ids
