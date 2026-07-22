class_name CharacterData

const DATA = {
	"bronya":    {"name":"布洛妮娅", "hp":68,  "move":5, "atk":15, "range":1,
		"skill":"护卫指令", "skill_desc":"为友方单体提供 30 点护盾", "skill_cd":3,
		"passive":"铁壁", "passive_desc":"受到伤害 -20%，当生命值 <50% 时受到伤害 -35%）"},
	"seele":     {"name":"希儿",    "hp":65,  "move":6, "atk":18, "range":1,
		"skill":"相位突进", "skill_desc":"瞬移至 10 格范围内选定的单体目标旁并发动 1.2 倍强化攻击", "skill_cd":3,
		"passive":"暗影突袭", "passive_desc":"攻击满血敌人时伤害 +50%"},
	"elaina":    {"name":"伊蕾娜",  "hp":60,  "move":5, "atk":20, "range":3,
		"skill":"星尘爆裂", "skill_desc":"对 6 格范围内目标及周围 1 格敌人造成 25 点伤害", "skill_cd":4,
		"passive":"魔力共鸣", "passive_desc":"使用攻击/减益卡牌时，获得一层 [魔力充盈]，攻击力 +15%，持续 2 回合，最多可叠加 3 层"},
	"firefly":   {"name":"流萤",    "hp":85,  "move":5, "atk":14, "range":1,
		"skill":"烈焰冲锋", "skill_desc":"对 6 格范围内目标造成 25 点伤害并附加灼烧 2 回合", "skill_cd":3,
		"passive":"燃烧装甲", "passive_desc":"每回合首次受击时有 50% 概率反击灼烧"},
	"silverwolf":{"name":"银狼",    "hp":65,  "move":5, "atk":16, "range":2,
		"skill":"系统入侵", "skill_desc":"目标虚弱 + 迟缓各 3 回合", "skill_cd":4,
		"passive":"数据篡改", "passive_desc":"攻击时有 50% 概率对目标附加随机减益"},
	"hamster":   {"name":"芝士仓鼠","hp":48,  "move":6, "atk":26, "range":4,
		"skill":"动作如潮", "skill_desc":"立即获得 1 次额外行动，该技能不消耗行动次数", "skill_cd":3,
		"passive":"钢铁直架", "passive_desc":"消灭敌方后获得 1 次额外行动，获得一层 [嗜血成性]，效果为攻击力 +50%，持续两回合，最多可叠加 3 层"},
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
		_: return id[0].to_upper() + id.substr(1)
