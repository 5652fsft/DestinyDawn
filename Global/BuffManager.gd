extends Node

# ─── Buff 数据结构 ───
# target.buffs[buff_id] = [entry, entry, ...]  (stacks)
# entry = { "value": int, "remaining": int, "source_path": String }

func apply_buff(target: Node, buff_id: String, value: int, duration: int, source: Node = null) -> bool:
	if not target or not target.has_method("get_buffs"):
		return false
	var list: Array = target.get_buffs(buff_id)
	var data = BuffDatabase.get_buff_data(buff_id)
	if data and data.max_stacks > 1 and list.size() >= data.max_stacks:
		return false  # already at max stacks

	var entry = { "value": value, "remaining": duration, "source_path": source.get_path() if source else "" }
	_ref_entry(target, buff_id, entry, true)

	if target.has_method("rpc"):
		if multiplayer.has_multiplayer_peer():
			target.rpc("_sync_buffs", _pack(target))

	var preset = _preset_for(buff_id)
	if preset:
		if target.has_method("play_vfx_preset_safe"):
			target.play_vfx_preset_safe(preset)
		elif target.multiplayer and target.multiplayer.has_multiplayer_peer():
			target.rpc("_play_vfx_preset", preset)

	_emit(target)
	return true

func remove_buff(target: Node, buff_id: String, index: int = -1) -> bool:
	if not target or not target.has_method("get_buffs"):
		return false
	var list: Array = target.get_buffs(buff_id)
	if list.is_empty():
		return false

	if index < 0:
		target.buffs.erase(buff_id)
	else:
		list.remove_at(index)
		if list.is_empty():
			target.buffs.erase(buff_id)
		else:
			target.buffs[buff_id] = list

	_sync_and_emit(target)
	return true

func cleanse(target: Node, category: String = "all") -> int:
	if not target or not target.has_method("get_all_buffs"):
		return 0
	var removed = 0
	for buff_id in target.get_all_buffs().keys():
		var data = BuffDatabase.get_buff_data(buff_id)
		if category == "all" or (data and _cat_str(data.category) == category):
			target.buffs.erase(buff_id)
			removed += 1
	if removed > 0:
		_sync_and_emit(target)
	return removed

func tick_buffs(target: Node) -> Array[Dictionary]:
	# Process DOT/HOT — returns list of {buff_id, value, is_damage} for caller to apply
	var ticks: Array[Dictionary] = []
	if not target or not target.has_method("get_all_buffs"):
		return ticks
	for buff_id in target.get_all_buffs().keys():
		var data = BuffDatabase.get_buff_data(buff_id)
		if not data or not data.has_tick:
			continue
		var list: Array = target.buffs[buff_id]
		for entry in list:
			if data.type == BuffData.BuffType.DAMAGE_OVER_TIME:
				ticks.append({ "buff_id": buff_id, "value": entry.value, "is_damage": true })
			elif data.type == BuffData.BuffType.HEAL_OVER_TIME:
				ticks.append({ "buff_id": buff_id, "value": entry.value, "is_damage": false })
	return ticks

func decrement_all(target: Node) -> int:
	if not target or not target.has_method("get_all_buffs"):
		return 0
	var expired = 0
	for buff_id in target.get_all_buffs().keys():
		var list: Array = target.buffs[buff_id]
		var i = list.size() - 1
		while i >= 0:
			list[i].remaining -= 1
			if list[i].remaining <= 0:
				list.remove_at(i)
				expired += 1
			i -= 1
		if list.is_empty():
			target.buffs.erase(buff_id)
	if expired > 0:
		_sync_and_emit(target)
	return expired

func process(target: Node) -> Array[Dictionary]:
	var ticks = tick_buffs(target)
	decrement_all(target)
	return ticks

func get_total(target: Node, buff_id: String) -> int:
	var list: Array = _get_list(target, buff_id)
	if list.is_empty():
		return 0
	var total = 0
	for entry in list:
		total += entry.value
	return total

func get_total_by_type(target: Node, buff_type: int) -> int:
	if not target or not target.has_method("get_all_buffs"):
		return 0
	var total = 0
	for buff_id in target.get_all_buffs().keys():
		var data = BuffDatabase.get_buff_data(buff_id)
		if data and data.type == buff_type:
			total += get_total(target, buff_id)
	return total

func has_any(target: Node, buff_id: String) -> bool:
	return not _get_list(target, buff_id).is_empty()

func get_all(target: Node) -> Dictionary:
	if not target or not target.has_method("get_all_buffs"):
		return {}
	return target.get_all_buffs()

# ─── 封装 helper ───

static func _get_list(target: Node, buff_id: String) -> Array:
	if not target or not "buffs" in target:
		return []
	var d: Dictionary = target.buffs
	return d.get(buff_id, [])

func _ref_entry(target: Node, buff_id: String, entry: Dictionary, is_add: bool, existing: Array = []):
	var list = existing if existing else _get_list(target, buff_id)
	if is_add:
		list.append(entry)
	if not "buffs" in target:
		target.set("buffs", {})
	target.buffs[buff_id] = list

func _pack(target: Node) -> Dictionary:
	return (target.get_all_buffs() if target.has_method("get_all_buffs") else {}).duplicate(true)

func _sync_and_emit(target: Node):
	if target.has_method("rpc"):
		if multiplayer.has_multiplayer_peer():
			target.rpc("_sync_buffs", _pack(target))
	_emit(target)

func _emit(target: Node):
	if target.has_signal("buffs_changed"):
		target.buffs_changed.emit()

static func _preset_for(buff_id: String) -> String:
	match buff_id:
		"attack_buff", "defense_buff", "regen":
			return "buff"
		"attack_debuff", "move_debuff", "poison", "burn":
			return "debuff"
		_:
			return "buff"

static func _cat_str(cat: BuffData.Category) -> String:
	match cat:
		BuffData.Category.MAGIC: return "magic"
		BuffData.Category.PHYSICAL: return "physical"
		BuffData.Category.SPECIAL: return "special"
		_: return "all"
