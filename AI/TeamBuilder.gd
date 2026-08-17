class_name AITeamBuilder
extends RefCounted

# ==================== AI 配队 & 卡组生成 ====================
# 配队约束（用户确认：不做固定形态，只做软约束）：
#   - 至少 1 名核心输出：seele / elaina / hamster / richardovo / zephyr / anjing
#   - 至少 1 名功能辅助：bronya / silverwolf / anpan / karrigan
#   - 至少 1 名能扛伤害：firefly / bronya / M1DorG / zephyr / karrigan（firefly 为副C兼肉）
#   允许双辅助一输出、主C+副C+生存等灵活组合

const CORE_OUTPUT: Array[String] = ["seele", "elaina", "hamster", "richardovo", "zephyr", "anjing"]
const SUPPORT: Array[String] = ["bronya", "silverwolf", "anpan", "karrigan"]
const TANKY: Array[String] = ["firefly", "bronya", "M1DorG", "zephyr", "karrigan"]
const ALL_CHARS: Array[String] = [
	"bronya", "seele", "elaina", "firefly", "silverwolf", "hamster",
	"karrigan", "zephyr", "anpan", "M1DorG", "Richardovo", "anjing"
]

static func build_ai_team() -> Array[String]:
	var team: Array[String] = []
	for attempt in range(30):
		var pool = ALL_CHARS.duplicate()
		pool.shuffle()
		var trial: Array[String] = []
		trial.assign(pool.slice(0, 3))
		if _satisfies(trial):
			team = trial
			break
	if team.is_empty():
		# 兜底：1 输出 + 1 辅助 + 1 能扛（彼此不重复）
		team = [_pick_random(CORE_OUTPUT), _pick_random(SUPPORT), _pick_random(TANKY)]
	return team

static func _satisfies(team: Array[String]) -> bool:
	var has_output = false
	var has_support = false
	var has_tank = false
	for id in team:
		if id in CORE_OUTPUT:
			has_output = true
		if id in SUPPORT:
			has_support = true
		if id in TANKY:
			has_tank = true
	return has_output and has_support and has_tank

static func _pick_random(pool: Array[String]) -> String:
	var p = pool.duplicate()
	p.shuffle()
	return p[0]

# ==================== 卡组生成 ====================
# 8 张：约 3 张 1 费 + 3 张 2 费 + 2 张 3 费（0 费卡可选 1 张）
# 保证：至少 1 张治疗/护盾 + 至少 1 张 debuff，单卡最多 2 张

const HEAL_SHIELD_IDS: Array[String] = [
	"card_small_heal", "card_life_split", "card_regen", "card_shield_overload",
	"card_heal", "card_heal_wave", "card_shield", "card_ice_shield", "card_mass_heal"
]
const DEBUFF_IDS: Array[String] = [
	"card_weakness", "card_slow", "card_mark", "card_hemorrhage", "card_disarm"
]

static func build_ai_deck() -> Array[String]:
	var by_cost: Dictionary = {0: [], 1: [], 2: [], 3: []}
	for id in CardDatabase.get_all_card_ids():
		var c = CardDatabase.get_card(id)
		if c and by_cost.has(c.cost):
			by_cost[c.cost].append(id)
	for cost in by_cost:
		by_cost[cost].shuffle()

	var deck: Array[String] = []
	# 必带治疗/护盾（优先 1 费，其次 2 费）
	var heal_candidate = []
	for id in HEAL_SHIELD_IDS:
		if id in by_cost[1]:
			heal_candidate.append(id)
	if heal_candidate.is_empty():
		heal_candidate = []
		for id in HEAL_SHIELD_IDS:
			if id in by_cost[2]:
				heal_candidate.append(id)
	if not heal_candidate.is_empty():
		var picked = heal_candidate[randi() % heal_candidate.size()]
		deck.append(picked)
		by_cost[CardDatabase.get_card(picked).cost].erase(picked)
	# 必带 debuff（优先 1 费）
	var debuff_candidate = []
	for id in DEBUFF_IDS:
		if id in by_cost[1]:
			debuff_candidate.append(id)
	if not debuff_candidate.is_empty():
		var picked = debuff_candidate[randi() % debuff_candidate.size()]
		deck.append(picked)
		by_cost[1].erase(picked)

	# 目标：1 费 3 张、2 费 3 张、3 费 2 张（共 8）
	var target_counts = {1: 3, 2: 3, 3: 2}
	var used_count: Dictionary = {}
	for cost in [1, 2, 3]:
		while by_cost[cost].size() > 0 and deck.size() < 8:
			if _count_in_deck(deck, used_count, cost, target_counts):
				break
			var id = by_cost[cost].pop_front()
			if used_count.get(id, 0) >= 2:
				continue
			deck.append(id)
			used_count[id] = used_count.get(id, 0) + 1
	# 仍不满 8 张时补 0 费/任意剩余
	var remaining = []
	for cost in by_cost:
		for id in by_cost[cost]:
			remaining.append(id)
	remaining.shuffle()
	for id in remaining:
		if deck.size() >= 8:
			break
		if used_count.get(id, 0) >= 2:
			continue
		deck.append(id)
		used_count[id] = used_count.get(id, 0) + 1
	return deck

static func _count_in_deck(deck: Array[String], used_count: Dictionary, cost: int, target_counts: Dictionary) -> bool:
	var cost_count = 0
	for id in deck:
		if CardDatabase.get_card(id).cost == cost:
			cost_count += 1
	return cost_count >= target_counts[cost]