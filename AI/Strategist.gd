class_name AIStrategist
extends RefCounted

# ==================== AI 通用评估器 ====================
# 职责：提供 AI 决策所需的全部"查询 / 伤害模拟 / 评分 / 规划"能力
# 约定：
#   - 距离一律使用格子距离（HexUtils.hex_distance，与 BFS 步数一致），禁用像素距离
#   - 伤害模拟与 BaseCharacter.take_damage / 各角色被动公式保持一致
#   - 本文件全部为静态纯函数，不产生副作用，不修改游戏状态
# 角色专属打法策略见 AI/Playbook.gd，配队见 AI/TeamBuilder.gd

const AI_PID: int = 2
const KILL_SCORE: int = 1000
const CARD_KILL_SCORE: int = 220
const CARD_THRESHOLD: int = 20
const HAND_LIMIT: int = 5

# AI 当前控制方（"host"/"client"）：由 AIController 规划前显式设置，防止跨对局/跨方串场
static var ai_side: String = "client"

# AI 控制方对应的玩家 ID：host→1；client→联机 client_peer_id / 单机 2（AI_PID）
static func get_pid(side: String) -> int:
	if side == "host":
		return 1
	var cid = GlobalGameData.client_peer_id
	return cid if cid > 0 else AI_PID

# ==================== 查询辅助 ====================

static func get_ai_alive(main: Node) -> Array:
	var result = []
	for c in (GlobalGameData.host_characters if ai_side == "host" else GlobalGameData.client_characters):
		if is_instance_valid(c) and c.hp > 0:
			result.append(c)
	return result

static func get_enemy_alive(main: Node) -> Array:
	var result = []
	for c in (GlobalGameData.client_characters if ai_side == "host" else GlobalGameData.host_characters):
		if is_instance_valid(c) and c.hp > 0:
			result.append(c)
	return result

static func get_ally_alive(main: Node, except: Node = null) -> Array:
	var result = []
	for c in (GlobalGameData.host_characters if ai_side == "host" else GlobalGameData.client_characters):
		if c == except:
			continue
		if is_instance_valid(c) and c.hp > 0:
			result.append(c)
	return result

static func get_cell(c: Node) -> Vector2i:
	if not is_instance_valid(c):
		return Vector2i(-1, -1)
	return c.get_current_cell()

static func get_energy(main: Node) -> int:
	var es = main.get_node_or_null("EnergySystem")
	return es.get_energy(get_pid(ai_side)) if es else 0

static func get_energy_of(main: Node, chara: Node) -> int:
	var es = main.get_node_or_null("EnergySystem")
	if not es:
		return 0
	var pid = chara.owner_pid if chara.get("owner_pid") != null else get_pid(ai_side)
	return es.get_energy(pid)

static func get_max_energy(main: Node) -> int:
	var es = main.get_node_or_null("EnergySystem")
	return es.max_energy if es else 10

static func get_hand(main: Node) -> Array:
	var dm = main.get_node_or_null("DeckManager")
	return dm.get_hand(get_pid(ai_side)) if dm else []

static func get_hand_limit(main: Node) -> int:
	var dm = main.get_node_or_null("DeckManager")
	return dm.hand_limit if dm and dm.get("hand_limit") != null else HAND_LIMIT

static func has_buff(c: Node, buff_id: String) -> bool:
	if not is_instance_valid(c):
		return false
	var bm = c.get("buff_manager")
	return bm != null and bm.has_any(c, buff_id)

static func buff_stack_count(c: Node, buff_id: String) -> int:
	if not is_instance_valid(c):
		return 0
	var bm = c.get("buff_manager")
	if not bm:
		return 0
	return bm.get_total(c, buff_id)

static func count_own_buffs(c: Node) -> int:
	if not is_instance_valid(c) or not c.has_method("get_all_buffs"):
		return 0
	return c.get_all_buffs().keys().size()

static func hex_dist(a: Vector2i, b: Vector2i) -> int:
	return HexUtils.hex_distance(a, b)

static func count_enemies_near(main: Node, cell: Vector2i, radius: int) -> int:
	if cell == Vector2i(-1, -1):
		return 0
	var count = 0
	for e in get_enemy_alive(main):
		var e_cell = get_cell(e)
		if e_cell != Vector2i(-1, -1) and hex_dist(cell, e_cell) <= radius:
			count += 1
	return count

static func count_allies_near(main: Node, cell: Vector2i, radius: int, except: Node = null) -> int:
	if cell == Vector2i(-1, -1):
		return 0
	var count = 0
	for a in get_ally_alive(main, except):
		var a_cell = get_cell(a)
		if a_cell != Vector2i(-1, -1) and hex_dist(cell, a_cell) <= radius:
			count += 1
	return count

static func find_nearest_enemy(main: Node, chara: Node) -> Node:
	var start = get_cell(chara)
	if start == Vector2i(-1, -1):
		return null
	var nearest = null
	var min_dist = 99999
	for e in get_enemy_alive(main):
		var e_cell = get_cell(e)
		if e_cell == Vector2i(-1, -1):
			continue
		var d = hex_dist(start, e_cell)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

static func find_lowest_hp_ally(main: Node, except: Node = null) -> Node:
	var allies = get_ally_alive(main, except)
	if allies.is_empty():
		return null
	allies.sort_custom(func(a, b): return a.hp < b.hp)
	return allies[0]

static func find_lowest_hp_enemy(main: Node) -> Node:
	var enemies = get_enemy_alive(main)
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.hp < b.hp)
	return enemies[0]

static func find_highest_attack_enemy(main: Node) -> Node:
	var enemies = get_enemy_alive(main)
	if enemies.is_empty():
		return null
	var best = null
	var best_atk = -1
	for e in enemies:
		var a = e.effective_attack
		if a > best_atk:
			best_atk = a
			best = e
	return best

static func find_most_threatened_ally(main: Node, except: Node = null) -> Node:
	var best = null
	var best_score = 0
	for a in get_ally_alive(main, except):
		var a_cell = get_cell(a)
		if a_cell == Vector2i(-1, -1):
			continue
		var threat = count_enemies_near(main, a_cell, 2)
		if threat <= 0:
			continue
		var score = threat * 100 + (a.max_hp - a.hp)
		if score > best_score:
			best_score = score
			best = a
	return best

static func is_in_smoke(c: Node) -> bool:
	var cell = get_cell(c)
	return cell != Vector2i(-1, -1) and GlobalGameData.smoke_cells.has(cell)

# ==================== 伤害模拟（与实战公式一致） ====================

# 模拟 attacker 对 target 造成 base 点伤害的最终数值（护盾吸收前）
static func simulate_damage(attacker: Node, target: Node, base_dmg: int) -> int:
	var dmg = base_dmg
	# 攻击者被动加成
	if attacker.character_name == "Zephyr":
		var z_data = CharacterData.get_data("zephyr")
		dmg += int((attacker.max_hp - attacker.hp) * z_data["passive_damage_pct"])
	if attacker.character_name == "希儿" and target.hp >= target.max_hp:
		var s_data = CharacterData.get_data("seele")
		dmg = int(dmg * (1.0 + s_data["passive_full_hp_bonus"]))
	# 受击者被动：先于 MARK/防御（与 take_damage 覆写顺序一致）
	var tbm = target.get("buff_manager")
	if target.character_name == "Zephyr":
		var ascend_val = tbm.get_total(target, "ascend") if tbm else 0
		if ascend_val > 0:
			var z_data = CharacterData.get_data("zephyr")
			var ascend_bd = BuffDatabase.get_buff_data("ascend")
			var max_stacks = ascend_bd.max_stacks if ascend_bd else 2
			var reduction = clamp(ascend_val, 0, z_data["skill_buff_value"] * max_stacks)
			dmg = max(1, dmg * (100 - reduction) / 100)
	if target.character_name == "布洛妮娅":
		var b_data = CharacterData.get_data("bronya")
		var reduction = b_data["passive_reduction"]
		if target.hp < target.max_hp * b_data["passive_low_hp"]:
			reduction = b_data["passive_reduction_low"]
		dmg = int(dmg * (1.0 - reduction))
	# 受击者：标记（MARK 类型总值，百分比增伤）
	if tbm:
		var mark_pct = tbm.get_total_by_type(target, BuffData.BuffType.MARK)
		if mark_pct > 0:
			dmg = dmg * (100 + mark_pct) / 100
		# 受击者：防御/易伤
		var def_val = tbm.get_total(target, "defense_buff")
		if def_val != 0:
			dmg = max(1, dmg - def_val)
	return int(dmg)

# ==================== 攻击评分 ====================

# 从给定格子攻击 target 的价值：击杀极高优先级，其次血量/威胁/护盾
static func score_attack(attacker: Node, target: Node, main: Node) -> int:
	var dmg = simulate_damage(attacker, target, attacker.effective_attack)
	if target.hp + target.shield <= dmg:
		return KILL_SCORE + dmg
	var value = dmg
	value += min(60, target.hp)
	var a_cell = get_cell(attacker)
	var t_cell = get_cell(target)
	if a_cell != Vector2i(-1, -1) and t_cell != Vector2i(-1, -1) \
			and hex_dist(a_cell, t_cell) <= attacker.attack_range:
		value += min(50, target.effective_attack)
	value += int(target.shield * 0.5)
	return value

# 在指定格子评估最佳攻击目标（该格需在目标攻击射程内）
static func _best_attack_at(chara: Node, main: Node, cell: Vector2i) -> Dictionary:
	if cell == Vector2i(-1, -1):
		return {"use": false, "target": null, "value": 0}
	var best_target = null
	var best_value = -999
	for e in get_enemy_alive(main):
		var e_cell = get_cell(e)
		if e_cell == Vector2i(-1, -1):
			continue
		if hex_dist(cell, e_cell) <= chara.attack_range:
			var v = score_attack(chara, e, main)
			if v > best_value:
				best_value = v
				best_target = e
	if best_target:
		return {"use": true, "target": best_target, "value": best_value}
	return {"use": false, "target": null, "value": 0}

# ==================== 移动规划 ====================

# 是否有可攻击目标（当前位置或任一可达格），供不耗行动技能（芝士仓鼠等）评估使用价值
static func can_attack_someone(chara: Node, main: Node) -> bool:
	if not is_instance_valid(chara) or chara.hp <= 0:
		return false
	if GlobalGameData.character_attack_used.get(chara.name, false):
		var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
		if extra <= 0:
			return false
	var start = get_cell(chara)
	if start == Vector2i(-1, -1):
		return false
	if _best_attack_at(chara, main, start).get("use", false):
		return true
	for cell in _reachable_cells(chara, main):
		if _best_attack_at(chara, main, cell).get("use", false):
			return true
	return false

static func _reachable_cells(chara: Node, main: Node) -> Array[Vector2i]:
	var gl = chara.grid_layer
	var start = get_cell(chara)
	if not gl or start == Vector2i(-1, -1):
		return []
	var reachable: Dictionary = HexUtils.get_reachable_cells(gl, start, chara.effective_move_points,
		func(c: Vector2i) -> bool: return main.is_cell_occupied(c, chara),
		func(c: Vector2i) -> int: return chara.get_move_cost(c))
	reachable.erase(start)
	var result: Array[Vector2i] = []
	for c in reachable.keys():
		result.append(c)
	return result

static func _dist_to_nearest_enemy(cell: Vector2i, enemies: Array) -> int:
	var min_d = 99999
	for e in enemies:
		var e_cell = get_cell(e)
		if e_cell == Vector2i(-1, -1):
			continue
		var d = hex_dist(cell, e_cell)
		if d < min_d:
			min_d = d
	return min_d

static func _enemy_can_reach(cell: Vector2i, enemies: Array) -> bool:
	for e in enemies:
		var e_cell = get_cell(e)
		if e_cell == Vector2i(-1, -1):
			continue
		if hex_dist(cell, e_cell) <= e.attack_range:
			return true
	return false

static func _plan_passive_move(chara: Node, main: Node) -> Dictionary:
	var no_move = {"use": false, "target": null, "value": 0, "move_cell": Vector2i(-1, -1)}
	var start = get_cell(chara)
	if start == Vector2i(-1, -1):
		return no_move
	var reachable = _reachable_cells(chara, main)
	if reachable.is_empty():
		return no_move
	var enemies = get_enemy_alive(main)
	# 残血撤退：血量 < 35% 且处于敌人射程内 → 逃出射程
	if float(chara.hp) / chara.max_hp < 0.35 and _enemy_can_reach(start, enemies):
		var best_cell = start
		var best_dist = -1
		for cell in reachable:
			if _enemy_can_reach(cell, enemies):
				continue
			var d = _dist_to_nearest_enemy(cell, enemies)
			if d > best_dist:
				best_dist = d
				best_cell = cell
		if best_cell != start:
			return {"use": true, "target": null, "value": 5, "move_cell": best_cell}
		return no_move
	# 近战：逼近最近敌人
	if chara.attack_range <= 1:
		var nearest = find_nearest_enemy(main, chara)
		if nearest:
			var n_cell = get_cell(nearest)
			if n_cell == Vector2i(-1, -1):
				return no_move
			var best_cell = start
			var best_dist = 99999
			for cell in reachable:
				var d = hex_dist(cell, n_cell)
				if d < best_dist:
					best_dist = d
					best_cell = cell
			if best_cell != start:
				return {"use": true, "target": null, "value": 1, "move_cell": best_cell}
		return no_move
	# 远程：优先保持射程内且尽量远离敌人（优先走出敌射程）
	var best_cell = start
	var best_score = -999
	for cell in reachable:
		var d = _dist_to_nearest_enemy(cell, enemies)
		if d > chara.attack_range:
			continue
		var score = 10 - d - (25 if _enemy_can_reach(cell, enemies) else 0)
		if score > best_score:
			best_score = score
			best_cell = cell
	if best_cell != start:
		return {"use": true, "target": null, "value": 2, "move_cell": best_cell}
	# 射程内无落脚点（敌人在射程外）：主动向最近敌人推进，避免消极蹲家
	var nearest = find_nearest_enemy(main, chara)
	if nearest:
		var n_cell = get_cell(nearest)
		if n_cell != Vector2i(-1, -1):
			var push_cell = start
			var push_dist = 99999
			for cell in reachable:
				var d = hex_dist(cell, n_cell)
				if d < push_dist:
					push_dist = d
					push_cell = cell
			if push_cell != start:
				return {"use": true, "target": null, "value": 3, "move_cell": push_cell}
	return no_move

# 攻击规划：优先当前格攻击 → 移动后攻击 → 被动移动
static func _plan_attack(chara: Node, main: Node) -> Dictionary:
	var no_attack = {"use": false, "target": null, "value": 0, "move_cell": Vector2i(-1, -1)}
	if GlobalGameData.character_attack_used.get(chara.name, false):
		var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
		if extra <= 0:
			return no_attack
	var start = get_cell(chara)
	if start == Vector2i(-1, -1):
		return no_attack
	var best = _best_attack_at(chara, main, start)
	if best.get("use", false):
		return {"use": true, "target": best.target, "value": best.value, "move_cell": Vector2i(-1, -1)}
	var reachable = _reachable_cells(chara, main)
	var best_cell = Vector2i(-1, -1)
	var best_target = null
	var best_value = -999
	for cell in reachable:
		var r = _best_attack_at(chara, main, cell)
		if r.get("use", false) and r.value > best_value:
			best_value = r.value
			best_target = r.target
			best_cell = cell
	if best_cell != Vector2i(-1, -1):
		return {"use": true, "target": best_target, "value": best_value, "move_cell": best_cell}
	return _plan_passive_move(chara, main)

# ==================== 单元规划（技能 + 攻击 + 移动的组合） ====================

# 规划单个角色的完整动作序列，返回 {"actions": Array, "value": int}
# actions 元素: {"type": "move"/"attack"/"skill", ...}
#   move  : {"cell": Vector2i}
#   attack: {"target": Node}
#   skill : {"target": Node, "cell": Vector2i}（CELL 型技能用 cell）
static func plan_unit(chara: Node, main: Node) -> Dictionary:
	var empty = {"actions": [], "value": 0}
	if not is_instance_valid(chara) or chara.hp <= 0:
		return empty
	if chara.has_method("get_current_phase") and chara.get_current_phase() != "Active":
		return empty  # 离场（M1DorG 蔚蓝）角色不规划行动
	var skill_plan = AIPlaybook.evaluate_skill(chara, main)
	# 技能射程过滤：目标超出当前射程时，尝试移动到可覆盖目标的格子（技能与移动不冲突，可组合）
	var skill_move_cell = Vector2i(-1, -1)
	if skill_plan.get("use", false) and skill_plan.get("target") != null:
		var skill = chara.active_skill
		var c_cell = get_cell(chara)
		var t_cell = get_cell(skill_plan.target)
		if skill and skill.skill_range > 0:
			if c_cell == Vector2i(-1, -1) or t_cell == Vector2i(-1, -1):
				skill_plan = {"use": false, "target": null, "cell": Vector2i(-1, -1), "value": 0, "exclusive": false}
			elif not SkillEffect.get_cells_in_range(chara.grid_layer, c_cell, skill.skill_range).has(t_cell):
				# 从可达格中找能覆盖目标的最优格：优先离目标近（推进），同距取离当前位置近（省移动点）
				var best_cell = Vector2i(-1, -1)
				var best_d = 99999
				var best_local_d = 99999
				for cell in _reachable_cells(chara, main):
					if SkillEffect.get_cells_in_range(chara.grid_layer, cell, skill.skill_range).has(t_cell):
						var d = hex_dist(cell, t_cell)
						var local_d = hex_dist(cell, c_cell)
						if d < best_d or (d == best_d and local_d < best_local_d):
							best_d = d
							best_local_d = local_d
							best_cell = cell
				if best_cell != Vector2i(-1, -1):
					skill_move_cell = best_cell
				else:
					skill_plan = {"use": false, "target": null, "cell": Vector2i(-1, -1), "value": 0, "exclusive": false}
	var attack_plan = _plan_attack(chara, main)
	# 被动移动（射程内无敌人时的推进/拉扯）：从攻击计划剥离，只保留移动意图，
	# 避免生成 target=null 的无效攻击动作（执行时报"攻击目标无效"）
	var passive_move = attack_plan.get("use", false) and attack_plan.get("target") == null
	var passive_move_cell = attack_plan.get("move_cell", Vector2i(-1, -1)) if passive_move else Vector2i(-1, -1)
	if passive_move:
		attack_plan = {"use": false, "target": null, "value": 0, "move_cell": Vector2i(-1, -1)}
	var actions: Array = []
	var total = 0
	var move_cell = Vector2i(-1, -1)
	var skill_consumes_action = not chara.has_method("_consumes_attack_on_skill") or chara._consumes_attack_on_skill()

	if skill_plan.get("use", false):
		if skill_consumes_action:
			# 技能与普攻互斥：取价值更高者
			if attack_plan.get("use", false) and attack_plan.value > skill_plan.value:
				actions.append({"type": "attack", "character": chara, "target": attack_plan.target})
				total = attack_plan.value
				move_cell = attack_plan.get("move_cell", Vector2i(-1, -1))
			else:
				actions.append({"type": "skill", "character": chara,
					"target": skill_plan.target, "cell": skill_plan.get("cell", Vector2i(-1, -1))})
				total = skill_plan.value
		else:
			if skill_plan.get("exclusive", false):
				# 独占技能（M1DorG）：用技能后立即锁行动 → 先普攻再技能
				if attack_plan.get("use", false):
					actions.append({"type": "attack", "character": chara, "target": attack_plan.target})
					total += attack_plan.value
					move_cell = attack_plan.get("move_cell", Vector2i(-1, -1))
				actions.append({"type": "skill", "character": chara,
					"target": skill_plan.target, "cell": skill_plan.get("cell", Vector2i(-1, -1))})
				total += skill_plan.value
			elif AIPlaybook.can_repeat_skill(chara):
				# 无冷却不耗行动的技能（Zephyr）：同回合可连续释放，循环评估（每次用模拟状态模拟自伤/层数）
				var sim_state: Dictionary = {}
				var guard = 0
				while guard < 3:
					var sp = AIPlaybook.evaluate_skill(chara, main, sim_state)
					if not sp.get("use", false):
						break
					actions.append({"type": "skill", "character": chara,
						"target": sp.target, "cell": sp.get("cell", Vector2i(-1, -1))})
					total += sp.value
					sim_state = AIPlaybook.simulate_after_skill(chara, main, sp, sim_state)
					guard += 1
				if attack_plan.get("use", false):
					actions.append({"type": "attack", "character": chara, "target": attack_plan.target})
					total += attack_plan.value
					move_cell = attack_plan.get("move_cell", Vector2i(-1, -1))
			else:
				# 不耗行动的技能（仅芝士仓鼠 / Richardovo）：先放技能再攻击
				actions.append({"type": "skill", "character": chara,
					"target": skill_plan.target, "cell": skill_plan.get("cell", Vector2i(-1, -1))})
				total += skill_plan.value
				if attack_plan.get("use", false):
					actions.append({"type": "attack", "character": chara, "target": attack_plan.target})
					total += attack_plan.value
					if move_cell == Vector2i(-1, -1):
						move_cell = attack_plan.get("move_cell", Vector2i(-1, -1))
	elif attack_plan.get("use", false):
		actions.append({"type": "attack", "character": chara, "target": attack_plan.target})
		total = attack_plan.value
		move_cell = attack_plan.get("move_cell", Vector2i(-1, -1))

	# 技能移动组合：本回合选了 target 型技能且需移动进入射程时，采用技能移动（优先于被动移动）
	if move_cell == Vector2i(-1, -1) and skill_move_cell != Vector2i(-1, -1):
		for a in actions:
			if a.get("type") == "skill":
				move_cell = skill_move_cell
				break

	if move_cell != Vector2i(-1, -1):
		actions.push_front({"type": "move", "character": chara, "cell": move_cell})
	elif passive_move_cell != Vector2i(-1, -1) and actions.is_empty():
		# 本回合无任何攻击/技能动作时，执行被动移动（靠近/脱离），不附加无效攻击
		actions.push_front({"type": "move", "character": chara, "cell": passive_move_cell})
		total = max(total, 3)
	return {"actions": actions, "value": total}

# ==================== 卡牌规划 ====================

# 为 AI 规划整回合出牌序列（按分数贪心），返回 action 数组（{"type":"card","card_id","target"}）
static func plan_cards(main: Node, skip_ids: Dictionary = {}) -> Array:
	var result: Array = []
	var reserve = 0
	for c in get_ai_alive(main):
		reserve = max(reserve, _skill_energy_reserve(c, main))
	var budget = get_energy(main) - reserve
	if budget <= 0:
		return result
	var hand = get_hand(main)
	while true:
		var best_action: Dictionary = {}
		var best_score = -999
		for card_id in hand:
			if skip_ids.has(card_id):
				continue
			var card = CardDatabase.get_card(card_id)
			if not card:
				continue
			if card.cost > budget:
				continue
			var target = pick_card_target(card, main)
			var score = _score_card(card, target, main)
			if score > best_score:
				best_score = score
				best_action = {"type": "card", "card_id": card_id, "target": target, "cost": card.cost}
		if best_score < CARD_THRESHOLD:
			break
		result.append(best_action)
		budget -= int(best_action.cost)
		hand.erase(best_action.card_id)
	return result

# 为可用的耗能技能预留能量（Anjing 2 / あんパン 4），能量不足时无需预留
static func _skill_energy_reserve(chara: Node, main: Node) -> int:
	if not is_instance_valid(chara) or chara.hp <= 0:
		return 0
	var char_id = ""
	match chara.character_name:
		"Anjing":
			char_id = "anjing"
		"あんパン":
			char_id = "anpan"
	if char_id == "":
		return 0
	var cost = CharacterData.get_data(char_id).get("skill_energy", 0)
	return cost if get_energy(main) >= cost else 0

static func _score_card(card: CardData, target: Node, main: Node) -> int:
	match card.card_type:
		CardData.CardType.ATTACK:
			return _score_attack_card(card, target, main)
		CardData.CardType.HEAL:
			return _score_heal_card(card, target, main)
		CardData.CardType.SHIELD:
			return _score_shield_card(card, target, main)
		CardData.CardType.BUFF:
			return _score_buff_card(card, target, main)
		CardData.CardType.DEBUFF:
			return _score_debuff_card(card, target, main)
		CardData.CardType.TACTICAL:
			return _score_tactical_card(card, target, main)
		CardData.CardType.DISPLACE:
			return _score_displace_card(card, target, main)
	return 10

static func _card_base_damage(card: CardData) -> int:
	# 副数值卡（直伤存于 secondary_value）统一从卡牌数据读取，与执行器同源
	if card.secondary_value > 0:
		match card.id:
			"card_siphon", "card_overload", "card_frostbite":
				return card.secondary_value
	match card.effect_type:
		CardData.EffectType.DAMAGE, CardData.EffectType.AOE_DAMAGE, \
				CardData.EffectType.CHAIN_DAMAGE, CardData.EffectType.LINEAR_AOE:
			return card.effect_value
		CardData.EffectType.DAMAGE_OVER_TIME:
			return card.effect_value * 2
	return 0

static func _score_attack_card(card: CardData, target: Node, main: Node) -> int:
	if not is_instance_valid(target) or target.hp <= 0:
		return 0
	var base = _card_base_damage(card)
	if base <= 0:
		return 10
	# 目标侧减伤模拟（与 take_damage 一致：MARK → 防御）
	var dmg = base
	var tbm = target.get("buff_manager")
	if tbm:
		var mark_pct = tbm.get_total_by_type(target, BuffData.BuffType.MARK)
		if mark_pct > 0:
			dmg = dmg * (100 + mark_pct) / 100
		var def_val = tbm.get_total(target, "defense_buff")
		if def_val != 0:
			dmg = max(1, dmg - def_val)
	dmg = int(dmg)
	if card.id == "card_reckoning":
		dmg = dmg * max(1, count_own_buffs(target))
	if target.hp + target.shield <= dmg:
		return CARD_KILL_SCORE + dmg
	# 群体伤害：按命中数放大
	if card.target_type == CardData.TargetType.NONE and card.effect_type == CardData.EffectType.AOE_DAMAGE:
		var hits = get_enemy_alive(main).size()
		return dmg * hits + 10
	if card.effect_type in [CardData.EffectType.AOE_DAMAGE, CardData.EffectType.LINEAR_AOE]:
		var hits = 1 + count_enemies_near(main, get_cell(target), max(1, card.effect_radius))
		return dmg * hits + 10
	if card.effect_type == CardData.EffectType.CHAIN_DAMAGE:
		var hits = 1 + count_enemies_near(main, get_cell(target), 2)
		return dmg + hits * 5 + 10
	return dmg + 10

static func _score_heal_card(card: CardData, target: Node, main: Node) -> int:
	if not is_instance_valid(target):
		return 0
	if card.target_type == CardData.TargetType.NONE or card.effect_type == CardData.EffectType.AOE_HEAL:
		var missing = 0
		for c in get_ai_alive(main):
			missing += c.max_hp - c.hp
		if missing <= 0:
			return 0
		return min(90, 20 + missing / 3)
	var hp_pct = float(target.hp) / target.max_hp
	if hp_pct < 0.3:
		return 80
	elif hp_pct < 0.5:
		return 60
	elif hp_pct < 0.75:
		return 30
	return 10

static func _score_shield_card(card: CardData, target: Node, main: Node) -> int:
	if not is_instance_valid(target):
		return 0
	var hp_pct = float(target.hp) / target.max_hp
	if hp_pct < 0.4:
		return 60
	elif hp_pct < 0.7:
		return 40
	elif target.shield > 0:
		return 35
	return 20

static func _score_buff_card(card: CardData, target: Node, main: Node) -> int:
	if not is_instance_valid(target):
		return 0
	var value = 30
	if target.character_name == "Richardovo":
		value = 60
	if card.effect_type == CardData.EffectType.BUFF_ATTACK \
			and target.character_name in ["Richardovo", "Zephyr", "希儿", "芝士仓鼠", "Anjing"]:
		value += 10
	return value

static func _score_debuff_card(card: CardData, target: Node, main: Node) -> int:
	if not is_instance_valid(target) or target.hp <= 0:
		return 0
	match card.effect_type:
		CardData.EffectType.DEBUFF_ATTACK:
			if has_buff(target, "attack_debuff"):
				return 15
			return 40 + target.effective_attack
		CardData.EffectType.DEBUFF_MOVE:
			if has_buff(target, "move_debuff"):
				return 15
			return 40 + (20 if target.attack_range <= 1 else 0)
		CardData.EffectType.MARK:
			if has_buff(target, "mark"):
				return 15
			return 55
		CardData.EffectType.DAMAGE_OVER_TIME:
			return 30
	return 30

static func _score_tactical_card(card: CardData, target: Node, main: Node) -> int:
	match card.id:
		"card_overload":
			if get_energy(main) < get_max_energy(main) - 1:
				return 40
			return 5
		"card_draw":
			var hand_size = get_hand(main).size()
			if hand_size <= 2:
				return 45
			elif hand_size <= 4:
				return 25
			return 10
		"card_echo":
			var hand_size = get_hand(main).size()
			if hand_size <= 2:
				return 55
			elif hand_size <= 4:
				return 30
			return 10
		"card_cleanse":
			for c in get_ai_alive(main):
				if has_buff(c, "attack_debuff") or has_buff(c, "move_debuff") \
						or has_buff(c, "poison") or has_buff(c, "burn"):
					return 55
			return 5
	return 15

static func _score_displace_card(card: CardData, target: Node, main: Node) -> int:
	if not is_instance_valid(target):
		return 0
	var a_cell = get_cell(target)
	if a_cell == Vector2i(-1, -1):
		return 0
	var near = count_enemies_near(main, a_cell, 2)
	var dmg = int(card.effect_value)
	if target.hp + target.shield <= dmg:
		return CARD_KILL_SCORE + dmg
	return near * 20 + dmg

static func pick_card_target(card: CardData, main: Node) -> Node:
	match card.target_type:
		CardData.TargetType.NONE:
			return null
		CardData.TargetType.ALLY_SINGLE:
			if card.card_type == CardData.CardType.BUFF:
				return _pick_buff_target(main)
			return find_lowest_hp_ally(main)
		CardData.TargetType.ALLY_ALL:
			var allies = get_ai_alive(main)
			return allies[0] if not allies.is_empty() else null
		CardData.TargetType.ENEMY_SINGLE:
			if card.card_type == CardData.CardType.DEBUFF:
				return _pick_debuff_target(card, main)
			return _pick_damage_card_target(card, main)
		CardData.TargetType.ENEMY_ALL, CardData.TargetType.ALL_CHARACTERS:
			var enemies = get_enemy_alive(main)
			return enemies[0] if not enemies.is_empty() else null
	return null

static func _pick_damage_card_target(card: CardData, main: Node) -> Node:
	var base = _card_base_damage(card)
	if base > 0:
		for e in get_enemy_alive(main):
			var tbm = e.get("buff_manager")
			var dmg = base
			if tbm:
				var def_val = tbm.get_total(e, "defense_buff")
				if def_val != 0:
					dmg = max(1, dmg - def_val)
			if e.hp + e.shield <= dmg:
				return e
	return find_lowest_hp_enemy(main)

static func _pick_buff_target(main: Node) -> Node:
	for c in get_ai_alive(main):
		if c.character_name == "Richardovo":
			return c
	var threatened = find_most_threatened_ally(main)
	if threatened:
		return threatened
	return find_lowest_hp_ally(main)

static func _pick_debuff_target(card: CardData, main: Node) -> Node:
	var enemies = get_enemy_alive(main)
	if enemies.is_empty():
		return null
	match card.effect_type:
		CardData.EffectType.DEBUFF_ATTACK:
			for e in enemies:
				if not has_buff(e, "attack_debuff"):
					return find_highest_attack_enemy(main)
		CardData.EffectType.DEBUFF_MOVE:
			for e in enemies:
				if not has_buff(e, "move_debuff") and e.attack_range <= 1:
					return e
		CardData.EffectType.MARK:
			for e in enemies:
				if not has_buff(e, "mark"):
					return find_lowest_hp_enemy(main)
	return find_lowest_hp_enemy(main)

# ==================== 烟雾评估（karrigan） ====================

static func evaluate_smoke_cell(cell: Vector2i, main: Node, chara: Node) -> int:
	if cell == Vector2i(-1, -1):
		return 0
	return count_enemies_near(main, cell, 2) * 40 + count_allies_near(main, cell, 2, chara) * 15

static func find_best_smoke_cell(chara: Node, main: Node) -> Vector2i:
	var gl = chara.grid_layer
	var start = get_cell(chara)
	if not gl or start == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var best = Vector2i(-1, -1)
	var best_score = 0
	var cells = HexUtils.get_cells_in_range(gl, start, 8)
	for cell in cells:
		if cell == start or main.is_cell_occupied(cell, chara):
			continue
		var s = evaluate_smoke_cell(cell, main, chara)
		if s > best_score:
			best_score = s
			best = cell
	return best