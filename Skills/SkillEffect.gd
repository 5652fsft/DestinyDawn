class_name SkillEffect
extends Node

static func get_cells_in_range(grid_layer: TileMapLayer, start_cell: Vector2i, max_range: int) -> Dictionary:
	var cells: Dictionary = {}
	var open_list = [start_cell]
	var visited: Dictionary = {}
	visited[start_cell] = 0
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	while open_list.size() > 0:
		var cell = open_list.pop_front()
		var cost = visited[cell]
		cells[cell] = cost
		if cost >= max_range:
			continue
		for d in directions:
			var next_cell = cell + d
			if not visited.has(next_cell) and grid_layer.get_cell_source_id(next_cell) != -1:
				visited[next_cell] = cost + 1
				open_list.append(next_cell)
	return cells

static func execute_active(character: Node, skill: BaseSkill, target: Node, main: Node) -> bool:
	if not character or not skill or skill.is_passive:
		return false

	if not _is_valid_target_for_skill(character, skill, target):
		print("[Skill] %s 目标类型不匹配（%s）" % [character.character_name, skill.target_type])
		return false

	if skill.skill_range > 0:
		var grid_layer = character.grid_layer
		var char_cell = main._get_character_cell(character)
		var target_cell = main._get_character_cell(target)
		var reachable = get_cells_in_range(grid_layer, char_cell, skill.skill_range)
		if not reachable.has(target_cell):
			print("[Skill] %s 目标超出技能范围" % character.character_name)
			return false

	var char_name = character.character_name if "character_name" in character else ""

	match char_name:
		"布洛妮娅":
			return _bronya_active(character, target)
		"希儿":
			return _seele_active(character, target, main)
		"伊蕾娜":
			return _elaina_active(character, target, main)
		"流萤":
			return _firefly_active(character, target, main)
		"银狼":
			return _silverwolf_active(character, target, main)
		"芝士仓鼠":
			return _hamster_active(character, target, main)
		"karrigan":
			return _karrigan_active(character, target, main)
		"Zephyr":
			return _zephyr_active(character, target, main)
		"あんパン":
			return _anpan_active(character, target, main)
		_:
			push_warning("未知角色技能: ", char_name)
			return false

static func get_passive_modifier(character: Node, modifier_key: String, base_value: int) -> int:
	if not character:
		return base_value

	var char_name = character.character_name if "character_name" in character else ""

	match char_name:
		"布洛妮娅":
			return _bronya_passive(character, modifier_key, base_value)
		"希儿":
			return _seele_passive(character, modifier_key, base_value)
		_:
			return base_value

# === 布洛妮娅 被动：铁壁 ===
static func _bronya_passive(character: Node, modifier_key: String, base_value: int) -> int:
	if modifier_key != "incoming_damage":
		return base_value
	var reduction = 0.2
	var label = "铁壁[20%]"
	if character.hp < character.max_hp * 0.5:
		reduction = 0.35
		label = "铁壁[35%]"
	print("[Skill] %s [%s] 减免 %d%% 伤害" % [character.character_name, label, int(reduction * 100)])
	return int(base_value * (1.0 - reduction))

# === 布洛妮娅 主动：护卫指令 ===
static func _bronya_active(character: Node, target: Node) -> bool:
	if not target:
		return false
	if not "shield" in target:
		target.set("shield", 0)
	target.shield += 30
	if target.has_method("rpc"):
		target.rpc("_sync_shield", target.shield)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("bronya_skill", target)
	print("[Skill] %s [护卫指令] → %s 护盾 +30" % [character.character_name, target.name])
	return true

# === 希儿 被动：暗影突袭 ===
static func _seele_passive(character: Node, modifier_key: String, base_value: int) -> int:
	if modifier_key != "outgoing_damage":
		return base_value
	if not "last_target_hp" in character:
		return base_value
	if character.last_target_hp == null or character.last_target_hp >= character.last_target_max_hp:
		print("[Skill] %s [暗影突袭] 攻击满血目标，伤害 +50%%" % character.character_name)
		return int(base_value * 1.5)
	return base_value

# === 希儿 主动：相位突进 ===
static func _seele_active(character: Node, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	var target_cell = main._get_character_cell(target)
	if target_cell == Vector2i(-1, -1):
		return false
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var best_cell = null
	for d in directions:
		var neighbor = target_cell + d
		if not main.is_cell_occupied(neighbor) and character.grid_layer.get_cell_source_id(neighbor) != -1:
			best_cell = neighbor
			break
	if best_cell == null:
		print("[Warn] %s 无法找到 [相位突进] 的瞬移位置" % character.character_name)
		return false
	var target_local = character.grid_layer.map_to_local(best_cell)
	var world_pos = character.grid_layer.to_global(target_local)
	character.global_position = world_pos
	character.target_world = world_pos
	character.velocity = Vector2.ZERO
	if character.is_moving:
		character.is_moving = false
		main.end_character_move()
	if character.has_method("rpc") and character.multiplayer.has_multiplayer_peer():
		character.rpc("_sync_position", world_pos)
	if target.has_method("take_damage"):
		var bonus = int(character.attack * 1.2)
		target.take_damage_safe(bonus)
		var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("seele_skill", target)
		print("[Skill] %s [相位突进] → %s 造成 %d 点伤害" % [character.character_name, target.name, bonus])
	return true

# === 伊蕾娜 主动：星尘爆裂 ===
static func _elaina_active(character: Node, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	var dmg = 25
	var is_caster_host = character.name.begins_with("Host")
	# 主要目标
	if target.has_method("take_damage"):
		target.take_damage_safe(dmg)
	var target_cell = main._get_character_cell(target)
	var aoe_cells = get_cells_in_range(character.grid_layer, target_cell, 1)
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c != target and c.hp > 0 and c.name.begins_with("Host") != is_caster_host:
			var c_cell = main._get_character_cell(c)
			if aoe_cells.has(c_cell):
				c.take_damage_safe(dmg)
	target.play_vfx_preset_safe("explosion")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("elaina_skill", target)
	print("[Skill] %s [星尘爆裂] → %s 及周围造成 %d 点伤害" % [character.character_name, target.name, dmg])
	return true

# === 流萤 主动：烈焰冲锋 ===
static func _firefly_active(character: Node, target: Node, main: Node) -> bool:
	if not target:
		return false
	target.take_damage_safe(25)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("firefly_skill", target)
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("apply_buff"):
		bm.apply_buff(target, "burn", 5, 2, character)
	print("[Skill] %s [烈焰冲锋] → %s 造成 25 伤害 + 灼烧" % [character.character_name, target.name])
	return true

# === 银狼 主动：系统入侵 ===
static func _silverwolf_active(character: Node, target: Node, main: Node) -> bool:
	if not target:
		return false
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("apply_buff"):
		bm.apply_buff(target, "attack_debuff", -8, 3, character)
		bm.apply_buff(target, "move_debuff", -2, 3, character)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("silverwolf_skill", target)
	print("[Skill] %s [系统入侵] → %s 虚弱+迟缓 3 回合" % [character.character_name, target.name])
	return true

# === 芝士仓鼠 主动：动作如潮 ===
static func _hamster_active(character: Node, target: Node, main: Node) -> bool:
	if "_extra_attacks" in character:
		character._extra_attacks += 1
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("hamster_skill", character)
	print("[Skill] %s [动作如潮] 获得额外行动" % character.character_name)
	character.play_vfx_preset_safe("heal")
	return true

static func _anpan_active(character: Node, target: Node, main: Node) -> bool:
	var bm = main.get_node_or_null("BuffManager") if main else null
	var dm = main.get_node_or_null("DeckManager") if main else null
	var es = main.get_node_or_null("EnergySystem") if main else null
	if not dm or not es:
		return false
	var pid = 1 if character in GlobalGameData.host_characters else 2
	# 能量检查（需 6 点）
	if es.get_energy(pid) < 6:
		print("[Skill] あんパン [极速高温烘焙] 能量不足（需 6），当前 %d" % es.get_energy(pid))
		var main_node = main
		if main_node and main_node.has_method("show_toast"):
			main_node.show_toast("能量不足！需要 6 点能量")
		return false
	es.spend_energy(pid, 6)
	# 抽牌至上限
	var hand = dm.get_hand(pid)
	var to_draw = dm.hand_limit - hand.size()
	if to_draw > 0:
		dm.draw_cards(pid, to_draw)
	# 回能至上限
	es.set_energy(pid, 10)
	if bm and bm.has_method("apply_buff"):
		bm.apply_buff(character, "soften", 20, 3, character)
	var _am = Engine.get_singleton("AudioManager")
	if _am: _am.play_sfx("anpan_skill", character)
	print("[Skill] あんパン [极速高温烘焙] 消耗 6 能量，抽 %d 张牌，回满能量，获得[松软]" % to_draw)
	character.play_vfx_preset_safe("buff")
	return true

static func _zephyr_active(character: Node, target: Node, main: Node) -> bool:
	var self_dmg = max(1, int(character.hp * 0.2))
	# 自伤为真实伤害，跳过攀升减免
	character.hp = max(1, character.hp - self_dmg)
	if character.has_method("_spawn_float"):
		character._spawn_float(self_dmg)
	if character.has_method("_shake_camera"):
		character._shake_camera(3.0)
	if character.has_method("rpc") and character.multiplayer and character.multiplayer.has_multiplayer_peer():
		character.rpc("_sync_hp", character.hp)
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("apply_buff"):
		bm.apply_buff(character, "ascend", 10, 2, character)
	var _am = Engine.get_singleton("AudioManager")
	if _am: _am.play_sfx("zephyr_skill", character)
	print("[Skill] Zephyr [引煞赴烬] 自伤 %d，获得 1 层攀升" % self_dmg)
	character.play_vfx_preset_safe("buff")
	return true

static func _karrigan_active(character: Node, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	var target_cell = character.grid_layer.local_to_map(character.grid_layer.to_local(target.global_position))
	if character.grid_layer.get_cell_source_id(target_cell) == -1:
		return false
	var fm = main.get_node_or_null("FieldEffectManager") if main else null
	if fm and fm.has_method("place_smoke"):
		fm.place_smoke(target_cell, 3, 2, character.grid_layer)
	else:
		var directions = [
			Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1),
			Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)
		]
		var smoke_cells = [target_cell]
		var visited = {target_cell: 0}
		var queue = [target_cell]
		while queue.size() > 0:
			var cell = queue.pop_front()
			var cost = visited[cell]
			if cost >= 3:
				continue
			for d in directions:
				var next_cell = cell + d
				if not visited.has(next_cell) and character.grid_layer.get_cell_source_id(next_cell) != -1:
					visited[next_cell] = cost + 1
					smoke_cells.append(next_cell)
					queue.append(next_cell)
		for cell in smoke_cells:
			GlobalGameData.smoke_cells[cell] = 2
	var _am = Engine.get_singleton("AudioManager")
	if _am: _am.play_sfx("karrigan_skill", character)
	print("[Skill] karrigan [狂野·纵横烟中] 在 %s 周围 3 格展开烟雾" % character.character_name)
	character.play_vfx_preset_safe("buff")
	return true

static func _is_valid_target_for_skill(character: Node, skill: BaseSkill, target: Node) -> bool:
	if not target or not character:
		return false
	match skill.target_type:
		BaseSkill.SkillTarget.SELF:
			return target == character
		BaseSkill.SkillTarget.ALLY_SINGLE:
			return character.name.begins_with("Host") == target.name.begins_with("Host")
		BaseSkill.SkillTarget.ENEMY_SINGLE:
			return character.name.begins_with("Host") != target.name.begins_with("Host")
		BaseSkill.SkillTarget.NONE, BaseSkill.SkillTarget.CELL:
			return true
	return true
