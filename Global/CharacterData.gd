extends Node

const DATA = {
	"bronya":    {"name":"布洛妮娅", "hp":80,  "move":5, "atk":15, "range":1,
		"skill":"护卫指令", "skill_desc":"为单个友方提供 30 点护盾", "skill_cd":3,
		"passive":"铁壁", "passive_desc":"受到伤害 -20%（HP<50% 时 -35%）"},
	"seele":     {"name":"希儿",    "hp":65,  "move":6, "atk":18, "range":1,
		"skill":"相位突进", "skill_desc":"瞬移至目标旁并发动一次 1.2 倍强化攻击", "skill_cd":3,
		"passive":"暗影突袭", "passive_desc":"攻击满血敌人时伤害 +50%"},
	"elaina":    {"name":"伊蕾娜",  "hp":60,  "move":5, "atk":20, "range":3,
		"skill":"星尘爆裂", "skill_desc":"对目标及周围 1 格敌人造成 35 点伤害", "skill_cd":4,
		"passive":"魔力共鸣", "passive_desc":"连续使用攻击/减益卡时每张伤害 +15%（最多 3 层）"},
	"firefly":   {"name":"流萤",    "hp":90,  "move":5, "atk":14, "range":1,
		"skill":"烈焰冲锋", "skill_desc":"造成 25 点伤害并附加灼烧 2 回合", "skill_cd":3,
		"passive":"燃烧装甲", "passive_desc":"每回合首次受击 50% 概率反击灼烧"},
	"silverwolf":{"name":"银狼",    "hp":65,  "move":5, "atk":16, "range":2,
		"skill":"系统入侵", "skill_desc":"目标虚弱 + 迟缓各 3 回合", "skill_cd":4,
		"passive":"数据篡改", "passive_desc":"攻击时 50% 概率附加随机减益"},
}

static func get(id: String) -> Dictionary:
	return DATA.get(id, {})

static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in DATA:
		ids.append(k)
	return ids
