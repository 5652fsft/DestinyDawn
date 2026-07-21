class_name AIController
extends Node

var _Logger = null
func _log(msg: String, category: String = "AI"):
	if _Logger == null:
		_Logger = load("res://Global/AILogger.gd")
	if _Logger:
		_Logger.log(msg, category)

# === 动作队列 ===
var _action_queue: Array[Dictionary] = []
var _action_timer: float = 0.0
var _busy: bool = false
var _current_phase: int = -1

const ACTION_DELAY: float = 0.5

var _main: Node2D = null
var _energy_system: Node = null
var _deck_manager: Node = null
var _camera: Node2D = null

# 六边形邻居方向（奇数列偏移）
var _hex_dirs: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]


func _ready():
	_main = get_tree().current_scene
	_energy_system = _main.get_node("EnergySystem")
	_deck_manager = _main.get_node("DeckManager")
	_camera = _main.get_node("Camera")
	_log("AI 控制器就绪")


func _pan_to(chara: Node):
	if not _camera or not chara:
		return
	if _camera.has_method("is_tweening") and _camera.is_tweening():
		return
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_camera, "position", chara.position, 0.4)


func _process(_delta):
	if not GlobalGameData.is_ai_mode:
		return

	if not _is_ai_phase():
		_action_queue.clear()
		_busy = false
		_current_phase = -1
		return

	if GlobalGameData.current_turn_phase != _current_phase:
		if _current_phase != -1:
			_log("阶段变化: %d -> %d，清理旧队列" % [_current_phase, GlobalGameData.current_turn_phase])
		_action_queue.clear()
		_busy = false
		_current_phase = GlobalGameData.current_turn_phase

	if _busy:
		_action_timer -= _delta
		if _action_timer <= 0:
			_execute_current_action()
		return

	if _action_queue.is_empty():
		_build_action_queue()
		if _action_queue.is_empty():
			_log("无待执行动作，结束阶段", "EndTurn")
			_end_phase()
			return
		_busy = true
		_action_timer = ACTION_DELAY


func _is_ai_phase() -> bool:
	return _is_ai_turn()

func _is_ai_turn() -> bool:
	# AI 在 AI 自己控制的那一方回合才行动
	if GlobalGameData.is_host_turn:
		return GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.ENEMY_TURN
	else:
		return GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.PLAYER_TURN


# ==================== 动作队列构建 ====================

func _build_action_queue():
	_action_queue.clear()
	var ai_chars = _get_ai_alive()

	# 移动队列
	_log("构建移动队列，AI 存活角色: %d" % ai_chars.size(), "Queue")
	for chara in ai_chars:
		if GlobalGameData.character_move_used.get(chara.name, false):
			continue
		var target = _evaluate_move_target(chara)
		if target != Vector2i(-1, -1):
			_action_queue.append({
				"type": "move", "character": chara, "cell": target
			})
		else:
			_log("%s 无可用移动目标" % chara.character_name)

	# 攻击/技能/卡牌队列
	_log("构建攻击队列，AI 存活角色: %d" % ai_chars.size(), "Queue")
	for chara in ai_chars:
		if _should_use_skill(chara):
			var skill_target = _evaluate_skill_target(chara)
			if skill_target != null and is_instance_valid(skill_target) and skill_target.hp > 0:
				_action_queue.append({
					"type": "skill", "character": chara, "target": skill_target
				})
				_log("%s 将使用技能 -> %s" % [chara.character_name, skill_target.character_name])
		if _should_play_card(chara):
			var card_action = _evaluate_best_card(chara)
			if not card_action.is_empty():
				_action_queue.append(card_action)
				_log("%s 将使用卡牌: %s" % [chara.character_name, card_action.get("card_id", "?")])
		if not GlobalGameData.character_attack_used.get(chara.name, false) or (chara.has_method("_get_extra_attacks") and chara._get_extra_attacks() > 0):
			var attack_target = _evaluate_attack_target(chara)
			if attack_target != null:
				_action_queue.append({
					"type": "attack", "character": chara, "target": attack_target
				})
				_log("%s 将攻击 -> %s" % [chara.character_name, attack_target.character_name])


# ==================== 动作执行 ====================

func _execute_current_action():
	if _action_queue.is_empty():
		_busy = false
		return

	var action = _action_queue.pop_front()
	var chara = action.get("character")

	if not is_instance_valid(chara) or chara.hp <= 0:
		_log("跳过动作：角色已死亡或无效", "Execute")
		if _action_queue.is_empty():
			_busy = false
			_current_phase = -1
		else:
			_busy = true
			_action_timer = ACTION_DELAY * 0.3
		return

	var target = action.get("target")
	if target != null and (not is_instance_valid(target) or target.hp <= 0):
		_log("跳过动作：目标已死亡或无效", "Execute")
		_busy = true
		_action_timer = ACTION_DELAY * 0.3
		return

	var phase_before = GlobalGameData.current_turn_phase

	match action.type:
		"move":
			_execute_move(chara, action.cell)
			_pan_to(chara)
		"attack":
			_pan_to(chara)
			_execute_attack(chara, action.target)
		"skill":
			_pan_to(chara)
			_execute_skill(chara, action.target)
		"card":
			_pan_to(chara)
			_execute_card(chara, action.card_id, action.get("target"))

	var phase_after = GlobalGameData.current_turn_phase

	if _action_queue.is_empty():
		_busy = false
		if phase_before == phase_after and _is_ai_phase():
			_end_phase()
	else:
		_busy = true
		_action_timer = ACTION_DELAY


func _execute_move(chara: Node, cell: Vector2i):
	var gl = chara.grid_layer
	if not gl:
		_log("%s 移动失败：无 grid_layer" % chara.character_name, "Move")
		return

	# 防重叠：目标格子被占用时找最近空闲格子
	if _main.is_cell_occupied(cell, chara):
		var start = chara.get_current_cell()
		var free = _find_nearest_free_cell(chara, cell, start)
		if free != Vector2i(-1, -1):
			_log("%s 原目标 (%d,%d) 被占用，改到 (%d,%d)" % [chara.character_name, cell.x, cell.y, free.x, free.y], "Move")
			cell = free
		else:
			_log("%s 目标 (%d,%d) 被占用且无可用邻格，跳过移动" % [chara.character_name, cell.x, cell.y], "Move")
			return

	var target_local = gl.map_to_local(cell)
	var world_pos = gl.to_global(target_local)

	# 确保角色可见 + 还原调制
	if not chara.visible:
		chara.show()
		_log("%s 不可见，已强制显示" % chara.character_name, "Move")
	if chara.has_node("Sprite2D"):
		var spr = chara.get_node("Sprite2D")
		spr.modulate = Color.WHITE

	# 直接设置位置 + target_world（move_toward_target 看到 dist=0 就不动）
	chara.global_position = world_pos
	chara.target_world = world_pos
	chara.velocity = Vector2.ZERO
	GlobalGameData.character_move_used[chara.name] = true
	GlobalGameData.character_move_used_num += 1
	_log("%s 移动到 (%d, %d)，位置 %s" % [chara.character_name, cell.x, cell.y, world_pos], "Move")


# ==================== 防重叠 ====================

func _find_nearest_free_cell(chara: Node, target: Vector2i, start: Vector2i) -> Vector2i:
	var visited: Dictionary = {}
	visited[target] = true
	var queue = [target]
	while queue.size() > 0:
		var cur = queue.pop_front()
		if not _main.is_cell_occupied(cur, chara):
			var cost = chara.get_move_cost(cur)
			if cost > 0:
				return cur
		for d in _hex_dirs:
			var n = cur + d
			if visited.has(n):
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


func _execute_attack(chara: Node, target: Node):
	if not is_instance_valid(target) or target.hp <= 0:
		_log("%s 攻击目标无效" % chara.character_name, "Attack")
		return
	if GlobalGameData.character_attack_used.get(chara.name, false):
		var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
		if extra <= 0:
			_log("%s 已无行动次数，跳过攻击" % chara.character_name, "Attack")
			return
	_log("%s 攻击 -> %s" % [chara.character_name, target.character_name], "Attack")
	chara.perform_attack(target.get_path())
	# 确保行动次数消耗（perform_attack 内部可能因 multiplayer 判断跳过）
	if not GlobalGameData.character_attack_used.get(chara.name, false):
		var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
		if extra > 0:
			chara._consume_extra_attack()
		else:
			GlobalGameData.character_attack_used[chara.name] = true
			GlobalGameData.character_attack_used_num += 1


func _execute_skill(chara: Node, target: Node):
	if not is_instance_valid(target) or target.hp <= 0:
		_log("%s 技能目标无效" % chara.character_name, "Skill")
		return
	_log("%s 使用技能 -> %s" % [chara.character_name, target.character_name], "Skill")
	chara.use_active_skill(target)
	if chara.active_skill:
		chara.active_skill.current_cooldown = chara.active_skill.cooldown
	# 确保行动次数消耗
	if not chara.has_method("_consumes_attack_on_skill") or chara._consumes_attack_on_skill():
		if not GlobalGameData.character_attack_used.get(chara.name, false):
			GlobalGameData.character_attack_used[chara.name] = true
			GlobalGameData.character_attack_used_num += 1


func _execute_card(chara: Node, card_id: String, target: Node):
	var target_path = ""
	if target != null and is_instance_valid(target):
		target_path = target.get_path()
	_log("%s 使用卡牌 %s，目标: %s" % [chara.character_name, card_id, target_path if target_path else "无"], "Card")
	var prev_selected = _main.selected_character
	_main.selected_character = chara
	_main._execute_play_card(2, card_id, target_path)
	_main.selected_character = prev_selected


# ==================== 移动评估 ====================

func _evaluate_move_target(chara: Node) -> Vector2i:
	var gl = chara.grid_layer
	if not gl:
		return Vector2i(-1, -1)
	var start = chara.get_current_cell()
	if start == Vector2i(-1, -1):
		return Vector2i(-1, -1)

	var max_move = chara.effective_move_points
	var reachable = _bfs_reachable(chara, max_move)
	if reachable.is_empty():
		return Vector2i(-1, -1)

	var nearest_enemy = _find_nearest_enemy(chara)
	if not nearest_enemy:
		return _pick_farthest_from_start(reachable, start)

	var enemy_cell = nearest_enemy.get_current_cell()
	if enemy_cell == Vector2i(-1, -1):
		return _pick_farthest_from_start(reachable, start)

	if chara.attack_range <= 1:
		return _pick_closest_to_target(reachable, enemy_cell)
	else:
		var in_range = _filter_in_attack_range(reachable, enemy_cell, chara.attack_range)
		if in_range.is_empty():
			return _pick_closest_to_target(reachable, enemy_cell)
		return _pick_farthest_from_target(in_range, enemy_cell)


func _bfs_reachable(chara: Node, max_move: int) -> Array[Vector2i]:
	var gl = chara.grid_layer
	var start = chara.get_current_cell()
	if start == Vector2i(-1, -1):
		return []
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	visited[start] = true
	var queue = [{ "cell": start, "cost": 0 }]

	while queue.size() > 0:
		var current = queue.pop_front()
		for d in _hex_dirs:
			var next = current.cell + d
			if visited.has(next):
				continue
			var cost = chara.get_move_cost(next)
			if cost <= 0:
				visited[next] = true
				continue
			if current.cost + cost > max_move:
				continue
			if _main.is_cell_occupied(next, chara):
				visited[next] = true
				continue
			visited[next] = true
			result.append(next)
			queue.append({ "cell": next, "cost": current.cost + cost })

	return result


func _pick_closest_to_target(cells: Array[Vector2i], target: Vector2i) -> Vector2i:
	var best = cells[0]
	var best_dist = best.distance_squared_to(target)
	for c in cells:
		var d = c.distance_squared_to(target)
		if d < best_dist:
			best_dist = d
			best = c
	return best


func _pick_farthest_from_target(cells: Array[Vector2i], target: Vector2i) -> Vector2i:
	var best = cells[0]
	var best_dist = best.distance_squared_to(target)
	for c in cells:
		var d = c.distance_squared_to(target)
		if d > best_dist:
			best_dist = d
			best = c
	return best


func _pick_farthest_from_start(cells: Array[Vector2i], start: Vector2i) -> Vector2i:
	var best = cells[0]
	var best_dist = best.distance_squared_to(start)
	for c in cells:
		var d = c.distance_squared_to(start)
		if d > best_dist:
			best_dist = d
			best = c
	return best


func _filter_in_attack_range(cells: Array[Vector2i], enemy_cell: Vector2i, attack_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in cells:
		var dist = c.distance_squared_to(enemy_cell)
		if dist <= attack_range * attack_range:
			result.append(c)
	return result


# ==================== 攻击评估 ====================

func _evaluate_attack_target(chara: Node) -> Node:
	var enemies = _get_enemies_in_attack_range(chara)
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.hp < b.hp)
	return enemies[0]


func _get_enemies_in_attack_range(chara: Node) -> Array:
	var result = []
	var enemies = _get_enemy_alive()
	var chara_cell = chara.get_current_cell()
	if chara_cell == Vector2i(-1, -1):
		return result
	for e in enemies:
		var e_cell = e.get_current_cell()
		if e_cell == Vector2i(-1, -1):
			continue
		var dist = chara_cell.distance_squared_to(e_cell)
		if dist <= chara.attack_range * chara.attack_range:
			result.append(e)
	return result


# ==================== 技能评估 ====================

func _should_use_skill(chara: Node) -> bool:
	if not chara.active_skill:
		return false
	if chara.active_skill.current_cooldown > 0:
		return false
	if GlobalGameData.character_attack_used.get(chara.name, false):
		if not chara.has_method("_consumes_attack_on_skill") or chara._consumes_attack_on_skill():
			return false
	return true


func _evaluate_skill_target(chara: Node) -> Node:
	var name = chara.character_name
	var target: Node = null
	match name:
		"布洛妮娅":
			target = _find_lowest_hp_ally()
		"希儿":
			target = _find_killable_with_bonus(chara)
		"伊蕾娜":
			target = _find_best_aoe_target(chara)
		"流萤":
			target = _find_highest_value_enemy()
		"银狼":
			target = _find_highest_attack_enemy()
		"芝士仓鼠":
			target = _evaluate_attack_target(chara)
		_:
			return null
	if target and _is_skill_out_of_range(chara, target):
		_log("%s 技能目标 %s 超出范围" % [chara.character_name, target.character_name])
		return null
	return target


func _find_lowest_hp_ally() -> Node:
	var allies = _get_ai_alive()
	if allies.is_empty():
		return null
	allies.sort_custom(func(a, b): return a.hp < b.hp)
	return allies[0]


func _find_killable_with_bonus(chara: Node) -> Node:
	var enemies = _get_enemy_alive()
	var bonus_dmg = int(chara.attack * 1.2)
	for e in enemies:
		if e.hp <= bonus_dmg:
			return e
	return _find_lowest_hp_enemy()


func _find_best_aoe_target(chara: Node) -> Node:
	var enemies = _get_enemy_alive()
	var best = null
	var best_count = -1
	for e in enemies:
		var count = _count_enemies_near(e, 130.0)
		if count > best_count:
			best_count = count
			best = e
	return best if best_count >= 1 else _find_lowest_hp_enemy()


func _find_highest_value_enemy() -> Node:
	var enemies = _get_enemy_alive()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b):
		var score_a = a.hp + a.attack + a.shield
		var score_b = b.hp + b.attack + b.shield
		return score_a > score_b)
	return enemies[0]


func _find_highest_attack_enemy() -> Node:
	var enemies = _get_enemy_alive()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.attack > b.attack)
	return enemies[0]


func _find_lowest_hp_enemy() -> Node:
	var enemies = _get_enemy_alive()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.hp < b.hp)
	return enemies[0]


func _is_skill_out_of_range(chara: Node, target: Node) -> bool:
	var skill = chara.active_skill
	if not skill or skill.skill_range <= 0:
		return false
	var chara_cell = chara.get_current_cell()
	var target_cell = target.get_current_cell()
	if chara_cell == Vector2i(-1, -1) or target_cell == Vector2i(-1, -1):
		return true
	var reachable = SkillEffect.get_cells_in_range(chara.grid_layer, chara_cell, skill.skill_range)
	return not reachable.has(target_cell)


func _count_enemies_near(center: Node, radius: float) -> int:
	var count = 0
	var enemies = _get_enemy_alive()
	for e in enemies:
		if e == center:
			continue
		if center.global_position.distance_to(e.global_position) <= radius:
			count += 1
	return count


# ==================== 卡牌评估 ====================

func _should_play_card(chara: Node) -> bool:
	var hand = _deck_manager.get_hand(2)
	if hand.is_empty():
		return false
	for card_id in hand:
		var card = CardDatabase.get_card(card_id)
		if card and _energy_system.can_afford(2, card.cost):
			return true
	return false


func _evaluate_best_card(chara: Node) -> Dictionary:
	var hand = _deck_manager.get_hand(2)
	var best_action: Dictionary = {}
	var best_score = -999

	for card_id in hand:
		var card = CardDatabase.get_card(card_id)
		if not card:
			continue
		if not _energy_system.can_afford(2, card.cost):
			continue

		var target = _pick_target_for_card(card)
		var score = _score_card(card, chara, target)

		if score > best_score:
			best_score = score
			best_action = {
				"type": "card",
				"character": chara,
				"card_id": card_id,
				"target": target
			}

	if best_score >= 20:
		_log("最佳卡牌 %s 评分: %d" % [best_action.get("card_id", "?"), best_score], "CardEval")
		return best_action
	return {}


func _pick_target_for_card(card: CardData) -> Node:
	match card.target_type:
		CardData.TargetType.NONE:
			return null
		CardData.TargetType.SELF:
			return _get_first_ai_alive()
		CardData.TargetType.ALLY_SINGLE:
			return _find_lowest_hp_ally()
		CardData.TargetType.ALLY_ALL:
			return _get_first_ai_alive()
		CardData.TargetType.ENEMY_SINGLE:
			return _find_lowest_hp_enemy()
		CardData.TargetType.ENEMY_ALL:
			return _get_first_enemy_alive()
		CardData.TargetType.ALL_CHARACTERS:
			return _get_first_enemy_alive()
		_:
			return null


func _score_card(card: CardData, chara: Node, target: Node) -> int:
	var score = 0
	match card.card_type:
		CardData.CardType.ATTACK:
			if target and is_instance_valid(target) and target.hp <= card.effect_value:
				score += 100
			else:
				score += card.effect_value + 10
		CardData.CardType.HEAL:
			if target and is_instance_valid(target):
				var hp_pct = float(target.hp) / target.max_hp
				if hp_pct < 0.3:
					score += 80
				elif hp_pct < 0.5:
					score += 60
				elif hp_pct < 0.75:
					score += 30
				else:
					score += 10
			else:
				score += 10
		CardData.CardType.SHIELD:
			if target and is_instance_valid(target):
				var hp_pct = float(target.hp) / target.max_hp
				if hp_pct < 0.4:
					score += 60
				elif hp_pct < 0.7:
					score += 40
				else:
					score += 20
			else:
				score += 20
		CardData.CardType.BUFF:
			score += 30
		CardData.CardType.DEBUFF:
			if target and is_instance_valid(target) and target.hp > 0:
				score += 40
			else:
				score += 10
		CardData.CardType.TACTICAL:
			var hand_size = _deck_manager.get_hand(2).size()
			if hand_size <= 2:
				score += 50
			elif hand_size <= 4:
				score += 30
			else:
				score += 10
		CardData.CardType.DISPLACE:
			var enemies_near = _count_enemies_near(_get_first_ai_alive(), 200.0) if _get_first_ai_alive() else 0
			score += enemies_near * 20
		_:
			score += 10

	return score


# ==================== 辅助函数 ====================

func _end_phase():
	_log("AI 结束当前阶段，调用 advance_turn_phase", "EndTurn")
	_main.unselect_character(null, true)
	_main.rpc("advance_turn_phase")


func _get_ai_alive() -> Array:
	var result = []
	for c in GlobalGameData.client_characters:
		if is_instance_valid(c) and c.hp > 0:
			result.append(c)
	return result


func _get_enemy_alive() -> Array:
	var result = []
	for c in GlobalGameData.host_characters:
		if is_instance_valid(c) and c.hp > 0:
			result.append(c)
	return result


func _get_first_ai_alive() -> Node:
	var alive = _get_ai_alive()
	return alive[0] if alive.size() > 0 else null


func _get_first_enemy_alive() -> Node:
	var alive = _get_enemy_alive()
	return alive[0] if alive.size() > 0 else null


func _find_nearest_enemy(chara: Node) -> Node:
	var enemies = _get_enemy_alive()
	if enemies.is_empty():
		return null
	var nearest = null
	var min_dist = INF
	var chara_cell = chara.get_current_cell()
	if chara_cell == Vector2i(-1, -1):
		return null
	for e in enemies:
		var e_cell = e.get_current_cell()
		if e_cell == Vector2i(-1, -1):
			continue
		var dist = chara_cell.distance_squared_to(e_cell)
		if dist < min_dist:
			min_dist = dist
			nearest = e
	return nearest
