class_name SkillEffect
extends Node

static func execute_active(character: Node, skill: BaseSkill, target: Node, main: Node) -> bool:
	if not character or not skill or skill.is_passive:
		return false

	var char_name = character.character_name if "character_name" in character else ""

	match char_name:
		"布洛妮娅":
			return _bronya_active(character, target)
		"希儿":
			return _seele_active(character, target, main)
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
	if character.hp < character.max_hp * 0.5:
		reduction = 0.35
	return int(base_value * (1.0 - reduction))

# === 布洛妮娅 主动：护卫指令 ===
static func _bronya_active(character: Node, target: Node) -> bool:
	if not target:
		return false
	if not "shield" in target:
		target.set("shield", 0)
	target.shield += 30
	print("[Skill] 布洛妮娅为 %s 提供了 30 点护盾" % target.name)
	return true

# === 希儿 被动：暗影突袭 ===
static func _seele_passive(character: Node, modifier_key: String, base_value: int) -> int:
	if modifier_key != "outgoing_damage":
		return base_value
	if not "last_target_hp" in character:
		return base_value
	if character.last_target_hp == null or character.last_target_hp >= character.last_target_max_hp:
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
		print("[Skill] 希儿无法找到瞬移位置")
		return false
	var target_local = character.grid_layer.map_to_local(best_cell)
	character.target_world = character.grid_layer.to_global(target_local)
	character.is_moving = true
	main.start_character_move()
	if target.has_method("take_damage"):
		var bonus = int(character.attack * 1.2)
		target.rpc("take_damage", bonus)
		print("[Skill] 希儿对 %s 造成 %d 点伤害（相位突进）" % [target.name, bonus])
	return true
