class_name CardEffect
extends Node

# 执行卡牌效果：分派到具体效果函数（卡牌由玩家释放到目标，无 caster 概念）
static func execute(card: CardData, target: Node, main: Node) -> bool:
	if not card or not main:
		return false

	_apply_magic_resonance(card, main)

	match card.effect_type:
		CardData.EffectType.DAMAGE:
			if card.id == "card_reckoning":
				return _execute_reckoning(card, target, main)
			if card.id == "card_fireball":
				return _execute_fireball(card, target, main)
			if card.id == "card_ice_shard":
				return _execute_ice_shard(card, target)
			return _execute_damage(card, target, main)
		CardData.EffectType.HEAL:
			if card.id == "card_life_split":
				return _execute_life_split(card, target, main)
			return _execute_heal(card, target)
		CardData.EffectType.SHIELD:
			if card.id == "card_shield_overload":
				return _execute_shield_overload(card, target)
			return _execute_shield(card, target)
		CardData.EffectType.BUFF_ATTACK:
			if card.id == "card_double_edge":
				return _execute_double_edge(card, target)
			return _execute_buff_attack(card, target)
		CardData.EffectType.BUFF_DEFENSE:
			return _execute_buff_defense(card, target)
		CardData.EffectType.DEBUFF_ATTACK:
			return _execute_debuff_attack(card, target)
		CardData.EffectType.DEBUFF_MOVE:
			if card.id == "card_frostbite":
				return _execute_frostbite(card, target)
			return _execute_debuff_move(card, target)
		CardData.EffectType.TELEPORT:
			if card.id == "card_shadowstep":
				return _execute_shadowstep_new(card, target, main)
			return _execute_teleport(card, target, main)
		CardData.EffectType.SWAP:
			return _execute_swap(card, target, main)
		CardData.EffectType.EXTRA_MOVE:
			return _apply_temp_buff(target, "extra_move", card.effect_value, card.effect_duration)
		CardData.EffectType.DRAW_CARD:
			if card.id == "card_siphon":
				return _execute_siphon(card, target, main)
			if card.id == "card_overload":
				return _execute_overload(card, target, main)
			return _execute_draw_card(card, main)
		CardData.EffectType.CLEANSE:
			return _execute_cleanse(target)
		CardData.EffectType.AOE_DAMAGE:
			return _execute_aoe_damage(card, target, main)
		CardData.EffectType.AOE_HEAL:
			return _execute_aoe_heal(card, target, main)
		CardData.EffectType.CHAIN_DAMAGE:
			return _execute_chain_lightning_new(card, target, main)
		CardData.EffectType.DAMAGE_OVER_TIME:
			if card.id == "card_poison_blade":
				return _execute_poison_blade(card, target)
			return _apply_temp_buff(target, "poison", card.effect_value, card.effect_duration)
		CardData.EffectType.HEAL_OVER_TIME:
			return _apply_temp_buff(target, "regen", card.effect_value, card.effect_duration)
		CardData.EffectType.LINEAR_AOE:
			return _execute_linear_aoe(card, target, main)
		CardData.EffectType.MARK:
			return _apply_temp_buff(target, "mark", card.effect_value, card.effect_duration)
		_:
			push_warning("未知卡牌效果类型: ", card.effect_type)
			return false

# ==================== 基础效果（无亲和力） ====================

static func _execute_damage(card: CardData, target: Node, main: Node) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	_rpc_take_damage(target, card.effect_value)
	_card_projectile(main, target, "magic_bolt")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_reckoning(card: CardData, target: Node, main: Node) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	if not "buffs" in target:
		return _execute_damage(card, target, main)
	var buff_count = 0
	for key in target.buffs:
		buff_count += target.buffs[key].size()
	var dmg = max(1, card.effect_value * buff_count)
	if main.has_method("show_toast"):
		main.show_toast("[惩戒] %s 身上 %d 个 buff，造成 %d 点伤害" % [GlobalGameData.get_char_label(target), buff_count, dmg], 1.5)
	_rpc_take_damage(target, dmg)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_fireball(card: CardData, target: Node, main: Node) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	_rpc_take_damage(target, card.effect_value)
	_apply_temp_buff(target, "burn", card.secondary_value, card.secondary_duration)
	_card_projectile(main, target, "fireball")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_ice_shard(card: CardData, target: Node) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	_rpc_take_damage(target, card.effect_value)
	_apply_temp_buff(target, "move_debuff", -2, 1)
	var main = _get_main(target)
	_card_projectile(main, target, "ice_shard")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_heal(card: CardData, target: Node) -> bool:
	if not target or not "hp" in target or not "max_hp" in target:
		return false
	var heal_amount = min(card.effect_value, target.max_hp - target.hp)
	if heal_amount <= 0:
		return false
	if target.has_method("take_damage_safe"):
		target.take_damage_safe(-heal_amount)
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("take_damage", -heal_amount)
	else:
		target.hp = min(target.max_hp, target.hp + heal_amount)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("heal")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "heal")
	var main = _get_main(target)
	_card_projectile_arc(main, target, "heal_orb")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("heal", target)
	return true

static func _execute_life_split(card: CardData, target: Node, main: Node) -> bool:
	if not target or not "hp" in target or not "max_hp" in target:
		return false
	if target.hp >= target.max_hp:
		if not main or not main.has_method("draw_extra_card"):
			return false
		main.draw_extra_card(null, 1)
		if main.has_method("show_toast"):
			main.show_toast("[生命分流] 目标满血，额外抽 1 张牌", 1.5)
		return true
	var heal_amount = min(card.effect_value, target.max_hp - target.hp)
	if heal_amount <= 0:
		return false
	if target.has_method("take_damage_safe"):
		target.take_damage_safe(-heal_amount)
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("take_damage", -heal_amount)
	else:
		target.hp = min(target.max_hp, target.hp + heal_amount)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("heal")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "heal")
	return true

static func _execute_shield(card: CardData, target: Node) -> bool:
	if not target:
		return false
	if not "shield" in target:
		target.set("shield", 0)
	target.shield = target.shield + card.effect_value
	if target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_sync_shield", target.shield)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("shield")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "shield")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("shield", target)
	return true

static func _execute_shield_overload(card: CardData, target: Node) -> bool:
	if not target:
		return false
	if not "shield" in target:
		target.set("shield", 0)
	if target.shield > 0:
		target.shield = target.shield * 2
	else:
		target.shield = target.shield + card.effect_value
	if target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_sync_shield", target.shield)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("shield")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "shield")
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("shield", target)
	return true

static func _execute_buff_attack(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "attack_buff", card.effect_value, card.effect_duration)

static func _execute_double_edge(card: CardData, target: Node) -> bool:
	_apply_temp_buff(target, "attack_buff", card.effect_value, card.effect_duration)
	_apply_temp_buff(target, "defense_buff", -5, card.effect_duration)
	return true

static func _execute_buff_defense(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "defense_buff", card.effect_value, card.effect_duration)

static func _execute_debuff_attack(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "attack_debuff", -card.effect_value, card.effect_duration)

static func _execute_debuff_move(card: CardData, target: Node) -> bool:
	return _apply_temp_buff(target, "move_debuff", -card.effect_value, card.effect_duration)

static func _execute_frostbite(card: CardData, target: Node) -> bool:
	if target and target.has_method("take_damage"):
		_rpc_take_damage(target, card.secondary_value)
	_apply_temp_buff(target, "move_debuff", -card.effect_value, card.effect_duration)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_poison_blade(card: CardData, target: Node) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	_rpc_take_damage(target, card.secondary_value)
	_apply_temp_buff(target, "poison", card.effect_value, card.effect_duration)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_sword", target)
	return true

static func _apply_temp_buff(target: Node, buff_key: String, value: int, duration: int) -> bool:
	if not target:
		return false
	var main = target.get_tree().current_scene if target.get_tree() else null
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("apply_buff"):
		return bm.apply_buff(target, buff_key, value, duration)
	if not "buffs" in target:
		target.set("buffs", {})
	var entry = { "value": value, "remaining": duration }
	if not target.buffs.has(buff_key):
		target.buffs[buff_key] = []
	target.buffs[buff_key].append(entry)
	if target.has_method("rpc"):
		if target.multiplayer.has_multiplayer_peer():
			target.rpc("_sync_buffs", target.buffs.duplicate())
		var vfx_color = Color(1.0, 0.9, 0.2) if value > 0 else Color(0.6, 0.2, 0.8)
		if target.multiplayer.has_multiplayer_peer():
			target.rpc("_play_vfx", vfx_color, 0.25)
		else:
			target._play_vfx(vfx_color, 0.25)
	return true

# ==================== 位移/特殊效果（基于 target 操作） ====================

static func _execute_teleport(card: CardData, target: Node, main: Node) -> bool:
	if not target or not target.has_method("get_current_cell") or not target.has_method("get_grid_layer"):
		return false
	var gl = target.get_grid_layer()
	if not gl:
		return false
	var cell = target.get_current_cell()
	var valid = []
	for d in HexUtils.HEX_DIRS:
		var pick = cell + d
		if gl.get_cell_source_id(pick) != -1 and not main.is_cell_occupied(pick, target):
			valid.append(pick)
	if valid.is_empty():
		return false
	var pick = valid[randi() % valid.size()]
	var world_pos = gl.to_global(gl.map_to_local(pick))
	if target.has_method("teleport_safe"):
		target.teleport_safe(world_pos)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("entrance")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "entrance")
	if card.effect_value > 0 and target.has_method("take_damage"):
		_rpc_take_damage(target, card.effect_value)
	return true

static func _execute_shadowstep_new(card: CardData, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	if not target.has_method("get_current_cell") or not "grid_layer" in target:
		return false
	var gl = target.grid_layer
	if not gl:
		return false
	var target_cell = target.get_current_cell()
	var is_target_host = target.name.begins_with("Host")
	var furthest_enemy = null
	var furthest_dist = -1.0
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == target or c.hp <= 0:
			continue
		if c.name.begins_with("Host") == is_target_host:
			continue
		var e_cell = c.get_current_cell()
		if e_cell == Vector2i(-1, -1):
			continue
		var d = target_cell.distance_squared_to(e_cell)
		if d > furthest_dist:
			furthest_dist = d
			furthest_enemy = c
	if not furthest_enemy:
		return false
	var enemy_cell = furthest_enemy.get_current_cell()
	var best_cell = null
	for d in HexUtils.HEX_DIRS:
		var pick = enemy_cell + d
		if gl.get_cell_source_id(pick) != -1:
			if main.has_method("is_cell_occupied") and not main.is_cell_occupied(pick, target):
				best_cell = pick
				break
	if best_cell == null:
		return false
	var world_pos = gl.to_global(gl.map_to_local(best_cell))
	if target.has_method("teleport_safe"):
		target.teleport_safe(world_pos)
	if furthest_enemy.has_method("take_damage"):
		_rpc_take_damage(furthest_enemy, card.effect_value)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("entrance")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "entrance")
	if furthest_enemy.has_method("play_vfx_preset_safe"):
		furthest_enemy.play_vfx_preset_safe("hit")
	elif furthest_enemy.multiplayer and furthest_enemy.multiplayer.has_multiplayer_peer():
		furthest_enemy.rpc("_play_vfx_preset", "hit")
	var _am = Engine.get_singleton("AudioManager")
	if _am: _am.play_sfx("attack_magic", furthest_enemy)
	print("[Card] 暗影步：%s 瞬移至 %s 旁，造成 %d 点伤害" % [GlobalGameData.get_char_label(target), GlobalGameData.get_char_label(furthest_enemy), card.effect_value])
	return true

static func _execute_swap(card: CardData, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	var is_host = target.name.begins_with("Host")
	var swap_with = null
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == target or c.hp <= 0:
			continue
		if c.name.begins_with("Host") == is_host:
			continue
		if c.has_method("get_current_cell") and target.has_method("get_current_cell"):
			swap_with = c
			break
	if not swap_with:
		return false
	var target_pos = target.global_position
	var swap_pos = swap_with.global_position
	if target.has_method("teleport_safe"):
		target.teleport_safe(swap_pos)
	if swap_with.has_method("teleport_safe"):
		swap_with.teleport_safe(target_pos)
	if target.has_method("play_vfx_preset_safe"):
		target.play_vfx_preset_safe("entrance")
	elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_play_vfx_preset", "entrance")
	if swap_with.has_method("play_vfx_preset_safe"):
		swap_with.play_vfx_preset_safe("entrance")
	elif swap_with.multiplayer and swap_with.multiplayer.has_multiplayer_peer():
		swap_with.rpc("_play_vfx_preset", "entrance")
	return true

static func _execute_draw_card(card: CardData, main: Node) -> bool:
	if not main or not main.has_method("draw_extra_card"):
		return false
	main.draw_extra_card(null, card.effect_value)
	return true

static func _execute_siphon(card: CardData, target: Node, main: Node) -> bool:
	if target and target.has_method("take_damage"):
		_rpc_take_damage(target, card.secondary_value)
	if main and main.has_method("draw_extra_card"):
		main.draw_extra_card(null, 1)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_overload(card: CardData, target: Node, main: Node) -> bool:
	if not main or not target:
		return false
	var energy_node = main.get_node_or_null("EnergySystem")
	if energy_node and energy_node.has_method("set_energy"):
		var pid = SkillEffect.get_character_pid(target)
		var cur = energy_node.get_energy(pid)
		energy_node.set_energy(pid, cur + card.extra_value)
	if target and target.has_method("take_damage"):
		_rpc_take_damage(target, card.secondary_value)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("attack_magic", target)
	return true

static func _execute_aoe_damage(card: CardData, target: Node, main: Node) -> bool:
	if not main:
		return false
	var is_caster_host = main.current_card_player_id == 1 if "current_card_player_id" in main else true
	if target:
		is_caster_host = _is_host_side(target)
	var dmg = card.effect_value
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c.has_method("take_damage") and _is_host_side(c) != is_caster_host:
			_rpc_take_damage(c, dmg)
	return true

static func _execute_aoe_heal(card: CardData, target: Node, main: Node) -> bool:
	if not main:
		return false
	var is_caster_host = main.current_card_player_id == 1 if "current_card_player_id" in main else true
	if target:
		is_caster_host = _is_host_side(target)
	var val = card.effect_value
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c.has_method("take_damage") and _is_host_side(c) == is_caster_host:
			_rpc_take_damage(c, -val)
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("heal")
	return true

static func _execute_chain_lightning_new(card: CardData, primary: Node, main: Node) -> bool:
	if not primary or not main:
		return false
	_rpc_take_damage(primary, card.effect_value)
	var is_primary_host = _is_host_side(primary)
	var primary_cell = primary.get_current_cell() if primary.has_method("get_current_cell") else Vector2i(-1, -1)
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == primary or c.hp <= 0:
			continue
		if _is_host_side(c) != is_primary_host:
			continue
		if not c.has_method("get_current_cell"):
			continue
		var c_cell = c.get_current_cell()
		if c_cell == Vector2i(-1, -1) or primary_cell == Vector2i(-1, -1):
			continue
		var dist = _hex_distance(primary_cell, c_cell)
		if dist == 1:
			_rpc_take_damage(c, card.secondary_value)
		elif dist == 2:
			_rpc_take_damage(c, card.extra_value)
	if primary.has_method("play_vfx_preset_safe"):
		primary.play_vfx_preset_safe("explosion")
	elif primary.multiplayer and primary.multiplayer.has_multiplayer_peer():
		primary.rpc("_play_vfx_preset", "explosion")
	var _am = Engine.get_singleton("AudioManager")
	if _am: _am.play_sfx("attack_magic", primary)
	print("[Card] 闪电链：%s 主目标 %d 点伤害，溅射周围敌人" % [GlobalGameData.get_char_label(primary), card.effect_value])
	return true

static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = _offset_to_cube(a)
	var bc = _offset_to_cube(b)
	return max(abs(ac.x - bc.x), abs(ac.y - bc.y), abs(ac.z - bc.z))

static func _offset_to_cube(cell: Vector2i) -> Vector3i:
	var col = cell.x
	var row = cell.y
	var x = col - (row - (row & 1)) / 2
	var z = row
	var y = -x - z
	return Vector3i(x, y, z)

static func _execute_linear_aoe(card: CardData, target: Node, main: Node) -> bool:
	if not target or not main:
		return false
	var dir = Vector2.RIGHT
	var max_dist = card.effect_value
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == target:
			continue
		dir = (c.global_position - target.global_position).normalized()
		var to = c.global_position - target.global_position
		var dot = to.dot(dir)
		if dot > 0 and dot <= max_dist * HexUtils.HEX_SPACING:
			var lateral = to.length() - dot
			if lateral < 80.0:
				if c.has_method("take_damage_safe"):
					c.take_damage_safe(card.effect_value)
				elif c.multiplayer and c.multiplayer.has_multiplayer_peer():
					c.rpc("take_damage", card.effect_value)
				else:
					c.take_damage(card.effect_value)
	return true

# ==================== 通用工具 ====================

static func _get_characters_in_range(main: Node, center: Node, radius: int) -> Array:
	var chars: Array = []
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c == center:
			continue
		if center.global_position.distance_to(c.global_position) <= radius * HexUtils.HEX_SPACING:
			chars.append(c)
	return chars

static func _is_host_side(node: Node) -> bool:
	return node.name.begins_with("Host")

# 安全伤害调用：优先 take_damage_safe，无 peer 时直接调用
static func _rpc_take_damage(node: Node, amount: int):
	if node.has_method("take_damage_safe"):
		node.take_damage_safe(amount)
	elif node.multiplayer and node.multiplayer.has_multiplayer_peer():
		node.rpc("take_damage", amount)
	else:
		node.take_damage(amount)

# 魔力共鸣：伊蕾娜被动，施放攻击/减益卡牌时触发
static func _apply_magic_resonance(card: CardData, main: Node):
	var attack_types = [
		CardData.EffectType.DAMAGE, CardData.EffectType.AOE_DAMAGE,
		CardData.EffectType.CHAIN_DAMAGE, CardData.EffectType.DAMAGE_OVER_TIME,
		CardData.EffectType.LINEAR_AOE
	]
	var debuff_types = [
		CardData.EffectType.DEBUFF_ATTACK, CardData.EffectType.DEBUFF_MOVE,
		CardData.EffectType.MARK
	]
	if not (card.effect_type in attack_types or card.effect_type in debuff_types):
		return
	if not "characters" in main:
		return
	var caster_is_host = main.current_card_player_id == 1 if "current_card_player_id" in main else true
	for c in main.characters:
		if not c or not c.has_method("get_buffs"):
			continue
		if c.name.begins_with("Host") != caster_is_host:
			continue
		if c.character_name != "伊蕾娜":
			continue
		if c.hp <= 0:
			continue
		var bm = main.get_node_or_null("BuffManager")
		if bm and bm.has_method("apply_buff"):
			bm.apply_buff(c, "magic_flow", 15, 2)
			print("[Passive] %s [魔力充盈] 获得一层攻击力 +15%%" % GlobalGameData.get_char_label(c))
		return

static func _execute_cleanse(target: Node) -> bool:
	if not target:
		return false
	var main = target.get_tree().current_scene if target.get_tree() else null
	var bm = main.get_node_or_null("BuffManager") if main else null
	if bm and bm.has_method("cleanse"):
		return bm.cleanse(target, "all") > 0
	if "buffs" in target:
		target.buffs.clear()
	if target.multiplayer and target.multiplayer.has_multiplayer_peer():
		target.rpc("_sync_buffs", {})
	return true

static func _get_main(node: Node) -> Node:
	if node and node.get_tree():
		return node.get_tree().current_scene
	return null

static func _card_vfx(main: Node, target: Node, effect: String):
	if not target or not main:
		return
	var vfx = main.get_node_or_null("VFXManager")
	if vfx and vfx.has_method("play_at"):
		vfx.play_at(target.global_position, effect)

static func _card_projectile(main: Node, target: Node, preset: String):
	_card_vfx(main, target, "hit")

static func _card_projectile_arc(main: Node, target: Node, preset: String):
	_card_vfx(main, target, "heal")
