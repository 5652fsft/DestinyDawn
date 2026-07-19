# res://Characters/BaseCharacter.gd
extends CharacterBody2D

# === 属性 ===
const click_layer: int = 2
const speed: float = 1200.0
@export var character_name: String = "Character"
@export var move_points: int = 4
@export var max_hp: int = 100
var _hp: int = 100
var hp: int:
	get:
		return _hp
	set(value):
		_hp = value
		if main and main.has_method("_update_character_info_panel"):
			main._update_character_info_panel(self)
		if floating_bar:
			floating_bar.refresh()
@export var attack: int = 16
@export var attack_range: int = 2  # 默认近战，1格

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D

const FLOATING_BAR = preload("res://Characters/FloatingBar.tscn")
const FLOATING_NUM = preload("res://Effects/FloatingNumber.tscn")
var floating_bar: Node2D = null

# === 外部依赖 ===
@onready var main: Node2D = get_tree().current_scene
@onready var grid_layer: TileMapLayer = main.get_node("Map/Ground")
@onready var highlight_layer: TileMapLayer = main.get_node("Map/Highlight")

var buff_manager: Node:
	get:
		if _bm == null and main:
			_bm = main.get_node_or_null("BuffManager")
		return _bm
var _bm: Node = null

var vfx_manager: Node:
	get:
		if _vm == null and main:
			_vm = main.get_node_or_null("VFXManager")
		return _vm
var _vm: Node = null

signal buffs_changed

# === 状态变量 ===
var target_world: Vector2 = Vector2.ZERO
var valid_move_cells: Dictionary = {}  # key: Vector2i, value: int
var valid_attack_cells: Dictionary = {}
var is_moving: bool = false
var is_attacking: bool = false
var hit_tween: Tween = null
var hover_tween: Tween = null
var _is_hovered: bool = false
var _fb_origin_y: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var shield: int = 0
var buffs: Dictionary = {}  # {"buff_id": [{"value": int, "remaining": int}, ...]}

func get_buffs(buff_id: String) -> Array:
	return buffs.get(buff_id, [])

func get_all_buffs() -> Dictionary:
	return buffs

var highlight_overlays: Array[Node] = []

var is_selected: bool = false:
	set(value):
		is_selected = value
		sprite.modulate = Color.WHITE if not value else Color.YELLOW
		if floating_bar:
			floating_bar.show_selected(value)
		if value and get_current_phase() == "Move" and not GlobalGameData.character_move_used.get(name, false):
			show_move_range()
		elif not value and get_current_phase() == "Move":
			hide_move_range()
		elif value and get_current_phase() == "Attack" and not GlobalGameData.character_attack_used.get(name, false):
			show_attack_range()
		elif not value and get_current_phase() == "Attack":
			hide_attack_range()

func _enter_tree():
	if name.begins_with("Client"):
		var peer_id_str = name.get_slice("Client", 1).get_slice("Character", 0)
		set_multiplayer_authority(int(peer_id_str))

func _ready():
	_hp = max_hp
	main.register_character(self)
	add_to_group("characters")
	
	var idx = int(name.get_slice("_", 1))
	if name.begins_with("Host"):
		position = GlobalGameData.host_birth_point[idx]
	elif name.begins_with("Client"):
		position = GlobalGameData.client_birth_point[idx]
	
	collision_layer = click_layer
	collision_mask = 0
	sprite.modulate = Color.WHITE
	_base_sprite_scale = sprite.scale
	
	# 查找场景中集成的 FloatingBar，如果没有则动态创建
	floating_bar = get_node_or_null("FloatingBar")
	if not floating_bar:
		floating_bar = FLOATING_BAR.instantiate()
		floating_bar.z_index = 10
		add_child(floating_bar)
	floating_bar.refresh()
	_fb_origin_y = floating_bar.position.y
	
	# 对齐角色到格子中心
	if grid_layer:
		var local_pos = grid_layer.to_local(global_position)
		var cell: Vector2i = grid_layer.local_to_map(local_pos)
		var aligned_pos = grid_layer.to_global(grid_layer.map_to_local(cell))
		global_position = aligned_pos
		target_world = aligned_pos
		velocity = Vector2.ZERO

	_update_sprite_texture()

func _on_hover_enter():
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hover_tween.set_parallel(true)
	hover_tween.tween_property(sprite, "scale", Vector2(1.08, 1.08), 0.12)
	hover_tween.tween_property(sprite, "self_modulate", Color(1.2, 1.2, 1.15), 0.12)
	hover_tween.tween_property(sprite, "offset:y", -4.0, 0.12)
	if floating_bar:
		hover_tween.tween_property(floating_bar, "scale", Vector2(1.08, 1.08), 0.12)
		hover_tween.tween_property(floating_bar, "position:y", _fb_origin_y - 4.0, 0.12)

func _on_hover_exit():
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hover_tween.set_parallel(true)
	hover_tween.tween_property(sprite, "scale", _base_sprite_scale, 0.1)
	hover_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.1)
	hover_tween.tween_property(sprite, "offset:y", 0.0, 0.1)
	if floating_bar:
		hover_tween.tween_property(floating_bar, "scale", _base_sprite_scale, 0.1)
		hover_tween.tween_property(floating_bar, "position:y", _fb_origin_y, 0.1)

func _exit_tree():
	if main and main.has_method("unregister_character"):
		main.unregister_character(self)

func get_grid_layer() -> TileMapLayer:
	return grid_layer

func get_current_cell() -> Vector2i:
	if not grid_layer:
		return Vector2i(-1, -1)
	var local_pos = grid_layer.to_local(global_position)
	return grid_layer.local_to_map(local_pos)

func _update_sprite_texture():
	if not sprite:
		return
	var script_path = get_script().get_path()
	var char_id = script_path.get_file().get_basename()
	var is_host_side = name.begins_with("Host")
	var is_friendly = is_host_side == GlobalGameData.is_host
	var suffix = "_Blue.png" if is_friendly else "_Red.png"
	var tex = load("res://Assets/Sprites/Characters/%s%s" % [char_id, suffix])
	if tex:
		sprite.texture = tex
	if not grid_layer:
		return Vector2i(-1, -1)
	var local_pos = grid_layer.to_local(global_position)
	return grid_layer.local_to_map(local_pos)

func is_enemy(other: CharacterBody2D) -> bool:
	if other == null:
		return false
	return name.begins_with("Host") != other.name.begins_with("Host")

func get_move_cost(cell: Vector2i) -> int:
	if not grid_layer or not grid_layer.tile_set:
		return 1
	
	var source_id = grid_layer.get_cell_source_id(cell)
	if source_id == -1:
		return -1  # 无瓦片 = 不可通行
	
	var source = grid_layer.tile_set.get_source(source_id)
	var tile_name = source.get_name() if source else ""
	
	match tile_name:
		"grass", "normal": return 1
		"water": return 2
		"mountain": return -1
		"wall": return -1
		_: return 1

func show_move_range():
	valid_move_cells.clear()
	var char_local = grid_layer.to_local(global_position)
	var start_cell: Vector2i = grid_layer.local_to_map(char_local)
	
	if get_move_cost(start_cell) <= 0:
		print("[Warn] 起始格不可通行")
		return

	valid_move_cells[start_cell] = 0

	var open_list = []
	var closed: Dictionary = {}  # 只记录已处理或已排除的格子（值为 true）
	open_list.append({ "cell": start_cell, "cost": 0 })

	# 六边形邻居方向（Odd Columns）
	var directions = [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1)
	]

	while open_list.size() > 0:
		# 简单排序模拟优先队列（最小成本优先）
		open_list.sort_custom(func(a, b): return a.cost < b.cost)
		var current = open_list.pop_front()
		var cell: Vector2i = current.cell
		var total_cost: int = current.cost
		
		if closed.has(cell):
			continue
		closed[cell] = true

		for d in directions:
			var next_cell: Vector2i = cell + d
			if closed.has(next_cell):
				continue

			# 检查是否被其他角色占据
			if main.is_cell_occupied(next_cell, self):
				closed[next_cell] = true
				continue

			var cost = get_move_cost(next_cell)
			if cost <= 0:
				closed[next_cell] = true
				continue

			var new_cost = total_cost + cost
			if new_cost <= move_points:
				# 允许更优路径更新
				if not valid_move_cells.has(next_cell) or new_cost < valid_move_cells[next_cell]:
					valid_move_cells[next_cell] = new_cost
					open_list.append({ "cell": next_cell, "cost": new_cost })

	# 高亮所有可达格子（跳过起始格）
	for cell in valid_move_cells.keys():
		if cell != start_cell:
			#print("[Debug] 可达格子", cell)
			highlight_layer.set_cell(cell, 0, Vector2i.ZERO)  # 假设 Highlight 层 ID=0 有瓦片

	#print("[Debug] 起始格子: ", start_cell, " 可达格子数: ", valid_move_cells.size())

func show_attack_range():
	valid_attack_cells.clear()
	var char_local = grid_layer.to_local(global_position)
	var start_cell: Vector2i = grid_layer.local_to_map(char_local)
	valid_attack_cells[start_cell] = 0

	var open_list = []
	var closed: Dictionary = {}  # 只记录已处理或已排除的格子（值为 true）
	open_list.append({ "cell": start_cell, "cost": 0 })

	# 六边形邻居方向（Odd Columns）
	var directions = [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1)
	]

	while open_list.size() > 0:
		# 简单排序模拟优先队列（最小成本优先）
		open_list.sort_custom(func(a, b): return a.cost < b.cost)
		var current = open_list.pop_front()
		var cell: Vector2i = current.cell
		var total_cost: int = current.cost
		
		if closed.has(cell):
			continue
		closed[cell] = true

		for d in directions:
			var next_cell: Vector2i = cell + d
			if closed.has(next_cell):
				continue
			var cost = 1
			if cost <= 0:
				closed[next_cell] = true
				continue

			var new_cost = total_cost + cost
			if new_cost <= attack_range:
				# 允许更优路径更新
				if not valid_attack_cells.has(next_cell) or new_cost < valid_attack_cells[next_cell]:
					valid_attack_cells[next_cell] = new_cost
					open_list.append({ "cell": next_cell, "cost": new_cost })

	# 高亮所有可攻击角色
	for cell in valid_attack_cells.keys():
		var enemy = main.find_cell_occupant(cell)
		if cell != start_cell and enemy and is_enemy(enemy):
			if highlight_layer:
				highlight_layer.set_cell(cell, 0, Vector2i.ZERO)
			var hex = Polygon2D.new()
			var r = 68.0
			var pts: PackedVector2Array = []
			for k in range(6):
				var a = deg_to_rad(60 * k - 30)
				pts.append(Vector2(cos(a) * r, sin(a) * r))
			hex.polygon = pts
			hex.color = Color(1.0, 0.15, 0.15, 0.4)
			hex.z_index = 1
			hex.name = "AttackRangeHighlight"
			# 挂在 Sprite2D 下以跟随动画（缩放、偏移、悬停等）
			var spr = enemy.get_node_or_null("Sprite2D")
			if spr:
				spr.add_child(hex)
			else:
				enemy.add_child(hex)
			highlight_overlays.append(hex)

func hide_move_range():
	valid_move_cells.clear()
	if highlight_layer:
		highlight_layer.clear()
		
func hide_attack_range():
	valid_attack_cells.clear()
	for h in highlight_overlays:
		if is_instance_valid(h):
			h.queue_free()
	highlight_overlays.clear()
	if highlight_layer:
		highlight_layer.clear()

func get_current_phase() -> String:
	var phase = GlobalGameData.current_turn_phase
	var is_host = GlobalGameData.is_host
	match phase:
		GlobalGameData.TurnPhase.PLAYER_MOVE:
			return "Move" if is_host == GlobalGameData.is_host_turn else "Wait"
		GlobalGameData.TurnPhase.PLAYER_ATTACK:
			return "Attack" if is_host == GlobalGameData.is_host_turn else "Wait"
		GlobalGameData.TurnPhase.ENEMY_MOVE:
			return "Move" if is_host != GlobalGameData.is_host_turn else "Wait"
		GlobalGameData.TurnPhase.ENEMY_ATTACK:
			return "Attack" if is_host != GlobalGameData.is_host_turn else "Wait"
		_:
			return "Invalid"

func _is_mouse_over_ui() -> bool:
	var ctrl = get_viewport().gui_get_hovered_control()
	while ctrl:
		if ctrl is BaseButton or ctrl is LineEdit or ctrl is CardUI:
			return true
		ctrl = ctrl.get_parent()
	return false

func handle_move():
	if hp <= 0:
		return
	if Input.is_action_just_pressed("Click") and not _is_mouse_over_ui():
		if main.is_targeting:
			return
		if main.is_any_character_moving:
			return
		
		var mouse_pos = get_global_mouse_position()
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collision_mask = click_layer
		
		var results = space_state.intersect_point(query)
		var clicked_on_self = false
		for r in results:
			if r.collider == self and not is_selected:
				clicked_on_self = true
				break
			elif r.collider == self:
				main.unselect_character(self)
		
		if clicked_on_self:
			main.select_character(self)
	
		elif is_selected:
			if GlobalGameData.character_move_used.get(name, false):
				main.show_toast("该角色本回合已移动")
				print("[Warn] 本回合已移动！")
				return
			
			if grid_layer:
				var local_mouse = grid_layer.to_local(mouse_pos)
				var cell_coord: Vector2i = grid_layer.local_to_map(local_mouse)
			
				if not valid_move_cells.has(cell_coord):
					main.show_toast("超出移动范围")
					print("[Warn] 目标格子超出移动范围、不可达或被阻挡")
					return
				
				if main.is_cell_occupied(cell_coord, self):
					main.show_toast("该格子已被占据")
					print("[Warn] 目标格子已被占据！")
					return
				
				main.start_character_move()
				is_moving = true
				
				var target_local = grid_layer.map_to_local(cell_coord)
				target_world = grid_layer.to_global(target_local)
				print("[Move] %s → (%d, %d) 消耗 %d" % [name, cell_coord.x, cell_coord.y, valid_move_cells[cell_coord]])
				GlobalGameData.character_move_used[name] = true
				GlobalGameData.character_move_used_num += 1
			main.unselect_character(self)
			main.check_move()
	
func handle_attack():
	if hp <= 0:
		return
	if Input.is_action_just_pressed("Click") and not _is_mouse_over_ui():
		if main.is_targeting:
			return
		var mouse_pos = get_global_mouse_position()
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collision_mask = click_layer
		
		var results = space_state.intersect_point(query)
		
		# 情况1：点击自己 → 选中
		for r in results:
			if r.collider == self:
				if not is_selected:
					main.select_character(self)
				else:
					main.unselect_character(self)
				return
		
		# 情况2：已选中，点击敌人 → 攻击
		if is_selected:
			if GlobalGameData.character_attack_used.get(name, false):
				if _get_extra_attacks() <= 0:
					main.show_toast("该角色本回合已行动")
					print("[Warn] %s 本回合已行动" % name)
					main.unselect_character(self)
					return
			for r in results:
				var other = r.collider
				if other is CharacterBody2D and is_enemy(other) and other.hp > 0:
					if valid_attack_cells.has(other.grid_layer.local_to_map(other.grid_layer.to_local(other.global_position))):
						rpc("perform_attack", other.get_path())
						if _get_extra_attacks() > 0:
							_consume_extra_attack()
						else:
							GlobalGameData.character_attack_used_num += 1
							GlobalGameData.character_attack_used[name] = true
						main.unselect_character(self)
						main.check_attack()
						return
					else:
						main.show_toast("超出攻击范围")
						print("[Warn] %s 目标超出攻击范围！" % name)
						return
			# 点击空地 → 取消选中
			main.unselect_character(self)

func _get_extra_attacks() -> int:
	return 0

func _consume_extra_attack():
	pass

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	#if not is_multiplayer_authority():
		#return
	
	var target = get_node_or_null(target_path)
	if not target or not target is CharacterBody2D:
		return
	
	if get_current_phase() != "Attack":
		return
		
	if main:
		main.last_attacker = self
	target.rpc("take_damage", effective_attack)
	print("[Combat] %s → %s 造成 %d 点伤害" % [name, target.name, effective_attack])
	
	# 同步动画（所有客户端）
	rpc_id(0, "_play_attack_animation", target_path)

@rpc("call_local", "reliable")
func _play_attack_animation(target_path: NodePath):
	var target_node = get_node_or_null(target_path)
	if not target_node or not target_node.has_node("Sprite2D"):
		return

	var target_sprite: Sprite2D = target_node.get_node("Sprite2D")
	if not target_sprite:
		return

	var dir = sign(target_node.global_position.x - global_position.x)
	var lurch = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lurch.tween_property(sprite, "offset:x", dir * 12.0, 0.04)
	lurch.tween_property(sprite, "offset:x", 0.0, 0.06)

	# 攻击者白色闪烁
	var atk_flash = create_tween().set_parallel(true)
	atk_flash.tween_property(sprite, "self_modulate", Color(1.6, 1.6, 1.3), 0.03)
	atk_flash.tween_property(sprite, "self_modulate", Color.WHITE, 0.08).set_delay(0.03)

	# 受击反馈
	if target_node.hit_tween and target_node.hit_tween.is_running():
		target_node.hit_tween.kill()

	var target_color = Color.YELLOW if target_node.is_selected else Color.WHITE
	target_node.hit_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_LINEAR)
	target_node.hit_tween.tween_property(target_sprite, "modulate", Color(1.6, 1.0, 1.0), 0.04)
	target_node.hit_tween.tween_property(target_sprite, "modulate", target_color, 0.1).set_delay(0.04)
	# 受击缩放（弹性）
	target_node.hit_tween.tween_property(target_sprite, "scale", Vector2(1.08, 1.08), 0.04)
	target_node.hit_tween.tween_property(target_sprite, "scale", Vector2(0.95, 0.95), 0.06).set_delay(0.04)

	if vfx_manager and vfx_manager.has_method("play"):
		vfx_manager.play(target_node, "hit")

	_shake_camera(5.0)

@rpc("any_peer", "call_local", "reliable")
func _play_vfx_preset(preset: String):
	if vfx_manager and vfx_manager.has_method("play"):
		vfx_manager.play(self, preset)

@rpc("any_peer", "call_local", "reliable")
func _play_vfx(color: Color, duration: float = 0.2):
	if not sprite:
		return
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	var orig = sprite.modulate
	sprite.modulate = color
	hit_tween = create_tween()
	hit_tween.set_trans(Tween.TRANS_LINEAR)
	var restore = Color.YELLOW if is_selected else Color.WHITE
	hit_tween.tween_property(sprite, "modulate", restore, duration)

func _shake_camera(intensity: float):
	var cam = get_tree().current_scene.find_child("Camera", true, false)
	if cam and cam.has_method("shake"):
		cam.shake(intensity)

func _spawn_float(value: int, heal: bool = false, shield: bool = false):
	var num = FLOATING_NUM.instantiate()
	num.global_position = global_position + Vector2(0, -80)
	num.z_index = 100
	get_tree().current_scene.add_child(num)
	num.show_value(value, heal, shield)

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int):
	var is_host = name.begins_with("Host")
	if damage <= 0:
		hp = min(max_hp, hp - damage)
		_spawn_float(-damage, true)
		if multiplayer.is_server():
			var key = "host_healing_done" if is_host else "client_healing_done"
			GlobalGameData.battle_stats[key] += -damage
			print("[Combat] %s 恢复 %d 点 HP [%d/%d]" % [name, -damage, hp, max_hp])
			rpc_id(0, "_sync_hp", hp)
		return
	
	# MARK: take extra damage
	var mark_pct = buff_manager.get_total(self, "mark") if buff_manager else 0
	if mark_pct > 0:
		damage = damage * (100 + mark_pct) / 100
		print("[Buff] %s 被标记，额外承受 %d%% 伤害！" % [name, mark_pct])
	
	var absorbed = min(shield, damage)
	shield -= absorbed
	damage -= absorbed
	if absorbed > 0:
		_spawn_float(absorbed, false, true)
		if multiplayer.is_server():
			print("[Combat] %s 护盾吸收 %d 点伤害，剩余护盾: %d" % [name, absorbed, shield])
	
	hp = max(0, hp - damage)
	_spawn_float(damage)
	_shake_camera(3.0)
	if multiplayer.is_server():
		var key = "host_damage_dealt" if not is_host else "client_damage_dealt"
		GlobalGameData.battle_stats[key] += damage
		print("[Combat] %s 受到 %d 点伤害，剩余 HP: %d" % [name, damage, hp])
	if hp <= 0:
		if not visible:
			return
		hide()
		collision_layer = 0
		# 击杀再动：攻击者重置行动状态
		if main and main.last_attacker and main.last_attacker.hp > 0:
			var killer = main.last_attacker
			if GlobalGameData.character_attack_used.has(killer.name):
				GlobalGameData.character_attack_used[killer.name] = false
				GlobalGameData.character_attack_used_num -= 1
		main.unregister_character(self)
		if multiplayer.is_server():
			var killer_key = "client_kills" if is_host else "host_kills"
			GlobalGameData.battle_stats[killer_key] += 1
	if multiplayer.is_server():
		rpc_id(0, "_sync_hp", hp)
		rpc_id(0, "_sync_shield", shield)

@rpc("any_peer", "call_local", "reliable")
func _sync_hp(new_hp: int):
	hp = new_hp
	if hp <= 0:
		hide()
		collision_layer = 0
		main.unregister_character(self)

var effective_attack: int:
	get:
		var base = attack
		if buff_manager:
			base += buff_manager.get_total(self, "attack_buff")
			base += buff_manager.get_total(self, "attack_debuff")
			var bt = buff_manager.get_total(self, "bloodthirst")
			if bt > 0:
				base += int(attack * bt / 100.0)
		return max(0, base)

var effective_move_points: int:
	get:
		var base = move_points
		if buff_manager:
			base -= buff_manager.get_total(self, "move_debuff")
			base += buff_manager.get_total(self, "extra_move")
		return max(1, base)

func process_buffs():
	if not buff_manager:
		return
	var ticks = buff_manager.process(self)
	buff_manager._sync_and_emit(self)
	# apply DOT/HOT ticks
	for t in ticks:
		if t.is_damage:
			rpc("take_damage", t.value)
		else:
			rpc("take_damage", -t.value)

@rpc("any_peer", "call_local", "reliable")
func _sync_shield(new_shield: int):
	shield = new_shield
	if floating_bar:
		floating_bar.refresh()

@rpc("any_peer", "call_local", "reliable")
func _sync_buffs(new_buffs: Dictionary):
	buffs = new_buffs
	buffs_changed.emit()

func _check_hover():
	var space = get_world_2d().direct_space_state
	var mouse_pos = get_global_mouse_position()
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collision_mask = click_layer
	var results = space.intersect_point(query)
	var hovered = false
	for r in results:
		if r.collider == self:
			hovered = true
			break
	if hovered and not _is_hovered:
		_is_hovered = true
		_on_hover_enter()
	elif not hovered and _is_hovered:
		_is_hovered = false
		_on_hover_exit()

func _process(delta):
	_check_hover()
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		move_toward_target()
		return
	if not is_multiplayer_authority():
		return
	if name.begins_with("Host") != GlobalGameData.is_host:
		return
	
	if get_current_phase() == "Move":
		handle_move()
	elif get_current_phase() == "Attack":
		handle_attack()

	move_toward_target()

func move_toward_target():
	var dist = global_position.distance_to(target_world)
	if dist > 5:
		velocity = global_position.direction_to(target_world) * speed
	else:
		global_position = target_world
		velocity = Vector2.ZERO
		is_moving = false
		if is_multiplayer_authority() and multiplayer.has_multiplayer_peer():
			rpc("_sync_position", global_position)
		main.end_character_move()
	move_and_slide()

@rpc("call_local", "reliable")
func _sync_position(pos: Vector2):
	target_world = pos
	global_position = pos
