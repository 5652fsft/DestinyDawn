class_name AIController
extends Node

func _log(msg: String, category: String = "AI"):
	print("[%s] %s" % [category, msg])

func _char_label(c) -> String:
	if not c:
		return "?"
	var cname = c.get("character_name")
	if cname == null or cname == "":
		return str(c.name)
	var is_player_side = c.name.begins_with("Host") == GlobalGameData.is_host
	return ((GlobalGameData.player_name + "/") if is_player_side else (GlobalGameData.opponent_name + "/")) + str(cname)

var _action_queue: Array[Dictionary] = []
var _action_timer: float = 0.0
var _busy: bool = false
var _current_phase: int = -1

const ACTION_DELAY: float = 0.5

var _main: Node2D = null
var _energy_system: Node = null
var _deck_manager: Node = null
var _camera: Node2D = null
var _camera_tween: Tween = null

# 本回合出牌失败记录（防止无限重试同一张卡）
var _card_skip: Dictionary = {}


func _ready():
	_main = get_tree().current_scene
	_energy_system = _main.get_node_or_null("EnergySystem")
	_deck_manager = _main.get_node_or_null("DeckManager")
	_camera = _main.get_node_or_null("Camera")
	_log("AI 控制器就绪")


func _pan_to(chara: Node):
	if not _camera or not chara:
		return
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "_target_position", chara.position, 0.4)
	_camera_tween.finished.connect(func(): _camera_tween = null, CONNECT_ONE_SHOT)


func _focus_on_player_characters():
	if GlobalGameData.is_host_turn and GlobalGameData.battle_stats.get("turns_taken", 0) <= 1:
		return
	var alive = []
	for c in GlobalGameData.host_characters:
		if is_instance_valid(c) and c.hp > 0:
			alive.append(c)
	if alive.is_empty():
		return
	var avg = Vector2.ZERO
	for c in alive:
		avg += c.global_position
	avg /= alive.size()
	if _camera:
		if _camera_tween and _camera_tween.is_valid():
			_camera_tween.kill()
		_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_camera_tween.tween_property(_camera, "_target_position", avg, 0.6)
		_camera_tween.finished.connect(func(): _camera_tween = null, CONNECT_ONE_SHOT)

func stop_camera_tween():
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
		_camera_tween = null


func _process(_delta):
	if not GlobalGameData.is_ai_mode:
		return

	if GlobalGameData.current_turn_phase != _current_phase:
		# 轮到玩家回合时聚焦玩家角色（host 先手时 PLAYER_TURN 是玩家回合，client 先手时 ENEMY_TURN 是玩家回合）
		var is_enemy_phase = GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.ENEMY_TURN
		var is_my_turn = (GlobalGameData.is_host_turn == GlobalGameData.is_host) != is_enemy_phase
		if is_my_turn:
			_focus_on_player_characters()
		if _current_phase != -1:
			_log("回合变化: %d -> %d，清理旧队列" % [_current_phase, GlobalGameData.current_turn_phase])
		_action_queue.clear()
		_busy = false
		_card_skip.clear()
		_current_phase = GlobalGameData.current_turn_phase

	if not _is_ai_phase():
		if not _action_queue.is_empty():
			_action_queue.clear()
			_busy = false
		return

	if _busy:
		_action_timer -= _delta
		if _action_timer <= 0:
			_execute_current_action()
		return

	if _action_queue.is_empty():
		_plan_and_queue()
		if _action_queue.is_empty():
			_log("无待执行动作，结束回合", "EndTurn")
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


# ==================== 决策规划（Strategist + Playbook） ====================

# 回合内动作编排：先出牌（buff/能量联动），再按价值从高到低执行角色单元
func _plan_and_queue():
	_action_queue.clear()
	var ai_chars = AIStrategist.get_ai_alive(_main)
	_log("规划动作，AI 存活角色: %d" % ai_chars.size(), "Queue")

	# 1. 卡牌规划（先铺 buff / 回能 / 治疗，与技能能量联动）
	var card_actions = AIStrategist.plan_cards(_main, _card_skip)
	for action in card_actions:
		_action_queue.append(action)
		_log("AI 将使用卡牌: %s" % action.get("card_id", "?"), "Queue")

	# 2. 角色单元规划（技能 + 攻击 + 移动组合），按总价值排序
	var units = []
	for chara in ai_chars:
		var plan = AIStrategist.plan_unit(chara, _main)
		if not plan.get("actions", []).is_empty():
			units.append({"actions": plan.actions, "value": plan.value})
	units.sort_custom(func(a, b): return a.value > b.value)
	for u in units:
		for action in u.actions:
			_action_queue.append(action)
			var desc = action.get("type", "?")
			_log("AI %s 动作: %s" % [_char_label(action.get("character")), desc], "Queue")


# ==================== 动作执行 ====================

func _execute_current_action():
	if _action_queue.is_empty():
		_busy = false
		return

	var action = _action_queue.pop_front()
	var chara = action.get("character")

	if chara != null and (not is_instance_valid(chara) or chara.hp <= 0):
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
			_execute_skill(chara, action.target, action.get("cell", Vector2i(-1, -1)))
		"card":
			_pan_to(chara)
			_execute_card(action.card_id, action.get("target"))

	var phase_after = GlobalGameData.current_turn_phase

	if _action_queue.is_empty():
		_busy = false
		if phase_before == phase_after and _is_ai_phase():
			_end_phase()
	else:
		_busy = true
		_action_timer = ACTION_DELAY


# 执行移动：防重叠、占位、同步；停在烟格则重置移动（免费再动）
func _execute_move(chara: Node, cell: Vector2i):
	var gl = chara.grid_layer
	if not gl:
		_log("%s 移动失败：无 grid_layer" % _char_label(chara), "Move")
		return

	if cell == Vector2i(-1, -1):
		return

	# 防重叠：目标格子被占用时找最近空闲格子
	if _main.is_cell_occupied(cell, chara):
		var start = chara.get_current_cell()
		var free = _find_nearest_free_cell(chara, cell, start)
		if free != Vector2i(-1, -1):
			_log("%s 原目标 (%d,%d) 被占用，改到 (%d,%d)" % [_char_label(chara), cell.x, cell.y, free.x, free.y], "Move")
			cell = free
		else:
			_log("%s 目标 (%d,%d) 被占用且无可用邻格，跳过移动" % [_char_label(chara), cell.x, cell.y], "Move")
			return

	var target_local = gl.map_to_local(cell)
	var world_pos = gl.to_global(target_local)

	# 确保角色可见 + 还原调制
	if not chara.visible:
		chara.show()
		_log("%s 不可见，已强制显示" % _char_label(chara), "Move")
	if chara.has_node("Sprite2D"):
		var spr = chara.get_node("Sprite2D")
		spr.modulate = Color.WHITE

	# 直接设置位置 + target_world（move_toward_target 看到 dist=0 就不动）
	chara.global_position = world_pos
	chara.target_world = world_pos
	chara.velocity = Vector2.ZERO
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("move", chara)
	GlobalGameData.character_move_used[chara.name] = true
	GlobalGameData.character_move_used_num += 1
	# 烟格：停留后免费再动（与玩家规则一致）
	if GlobalGameData.smoke_cells.has(cell):
		GlobalGameData.character_move_used[chara.name] = false
		_log("%s 进入烟格，重置移动次数" % _char_label(chara), "Move")
	_log("%s 移动到 (%d, %d)，位置 %s" % [_char_label(chara), cell.x, cell.y, world_pos], "Move")


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
		for d in HexUtils.HEX_DIRS:
			var n = cur + d
			if visited.has(n):
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


# 执行攻击：格子距离射程校验 + 调用 perform_attack_safe
func _execute_attack(chara: Node, target: Node):
	if not is_instance_valid(target) or target.hp <= 0:
		_log("%s 攻击目标无效" % _char_label(chara), "Attack")
		return
	if GlobalGameData.character_attack_used.get(chara.name, false):
		var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
		if extra <= 0:
			_log("%s 已无行动次数，跳过攻击" % _char_label(chara), "Attack")
			return
	# 射程校验：统一用六边形格子距离（与玩家侧一致）
	var c_cell = chara.get_current_cell()
	var t_cell = target.get_current_cell()
	if c_cell == Vector2i(-1, -1) or t_cell == Vector2i(-1, -1) \
			or HexUtils.hex_distance(c_cell, t_cell) > chara.attack_range:
		_log("%s 攻击目标 %s 超出射程，跳过" % [_char_label(chara), _char_label(target)], "Attack")
		return
	_log("%s 攻击 -> %s" % [_char_label(chara), _char_label(target)], "Attack")
	chara.perform_attack(target.get_path())
	# 确保行动次数消耗（perform_attack 内部可能因 multiplayer 判断跳过）
	if not GlobalGameData.character_attack_used.get(chara.name, false):
		var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
		if extra > 0:
			chara._consume_extra_attack()
		else:
			GlobalGameData.character_attack_used[chara.name] = true
			GlobalGameData.character_attack_used_num += 1


# 执行技能：支持 CELL 型技能（构造临时 marker 定位，与 _server_execute_skill 同构）
func _execute_skill(chara: Node, target: Node, cell: Vector2i = Vector2i(-1, -1)):
	if target != null and (not is_instance_valid(target) or target.hp <= 0):
		_log("%s 技能目标无效" % _char_label(chara), "Skill")
		return
	var skill_target = target
	var marker: Node = null
	if skill_target == null and cell != Vector2i(-1, -1) and chara.active_skill \
			and chara.active_skill.target_type == BaseSkill.SkillTarget.CELL:
		marker = Node2D.new()
		marker.name = "AISkillTargetMarker"
		_main.Characters.add_child(marker)
		var gl = chara.grid_layer
		marker.global_position = gl.to_global(gl.map_to_local(cell))
		skill_target = marker
	var target_desc = "格(%d,%d)" % [cell.x, cell.y] if skill_target == null else _char_label(skill_target)
	_log("%s 使用技能 -> %s" % [_char_label(chara), target_desc], "Skill")
	var ok = chara.use_active_skill(skill_target)
	if marker:
		marker.queue_free()
	if not ok:
		_log("%s 技能释放失败，不消耗行动" % _char_label(chara), "Skill")
		return
	if chara.active_skill:
		chara.active_skill.current_cooldown = chara.active_skill.cooldown
	# 确保行动次数消耗
	if not chara.has_method("_consumes_attack_on_skill") or chara._consumes_attack_on_skill():
		if not GlobalGameData.character_attack_used.get(chara.name, false):
			GlobalGameData.character_attack_used[chara.name] = true
			GlobalGameData.character_attack_used_num += 1


# 执行卡牌：通过 DeckManager 打出（失败记入 skip，本回合不再尝试）
func _execute_card(card_id: String, target: Node):
	var card_data = CardDatabase.get_card(card_id)
	if not card_data:
		_log("卡牌 %s 不存在，跳过" % card_id, "Card")
		_card_skip[card_id] = true
		return
	var hand = _deck_manager.get_hand(AIStrategist.AI_PID)
	if card_id not in hand:
		_log("[%s] 已不在手牌中，跳过" % card_data.card_name, "Card")
		_card_skip[card_id] = true
		return
	if not _energy_system.can_afford(AIStrategist.AI_PID, card_data.cost):
		_log("能量不足，无法使用 [%s]（需 %d）" % [card_data.card_name, card_data.cost], "Card")
		_card_skip[card_id] = true
		return
	if target != null and (not is_instance_valid(target) or target.hp <= 0):
		_log("[%s] 目标已死亡，跳过" % card_data.card_name, "Card")
		_card_skip[card_id] = true
		return
	var ai_chars = AIStrategist.get_ai_alive(_main)
	var chara = ai_chars[0] if not ai_chars.is_empty() else null
	if not chara:
		_log("无存活角色，跳过出牌", "Card")
		return
	var target_path = ""
	if target != null and is_instance_valid(target):
		target_path = target.get_path()
	_log("AI 使用 [%s]，目标: %s" % [card_data.card_name, _char_label(target) if target and is_instance_valid(target) else "无"], "Card")
	var prev_selected = _main.selected_character
	_main.selected_character = chara
	_main._execute_play_card(AIStrategist.AI_PID, card_id, target_path)
	_main.selected_character = prev_selected


# ==================== 辅助函数 ====================

func _end_phase():
	_log("AI 结束当前回合，调用 advance_turn_phase", "EndTurn")
	_main.unselect_character(null, true)
	_main.advance_turn_phase()
