extends Node2D

var selected_character = null
var characters: Array[CharacterBody2D] = []
var cell_occupancy: Dictionary = {}
var is_any_character_moving: bool = false

# === 卡牌系统 ===
var pending_card_data: CardData = null
var is_targeting: bool = false

@onready var ground_layer: TileMapLayer = $Map/Ground
@onready var highlight_layer: TileMapLayer = $Map/Highlight
@onready var Characters:Node2D = $Characters
@onready var character_info_panel = $UI/CharacterInfoPanel
@onready var turn_indicator = $UI/TurnIndicator
@onready var hand_panel = $UI/HandPanel
@onready var energy_system = $EnergySystem
@onready var deck_manager = $DeckManager
@onready var skill_panel = $UI/SkillPanel
@onready var host_player_panel = $UI/HostPlayerPanel
@onready var client_player_panel = $UI/ClientPlayerPanel

const CHARACTER_bronya = preload("res://Characters/Bronya/bronya.tscn")
const CHARACTER_seele = preload("res://Characters/Seele/seele.tscn")

# === 默认卡组（临时：Phase 4 将改为战前选择） ===
var default_deck: Array[String] = [
	"card_fireball", "card_fireball",
	"card_ice_shard", "card_ice_shard",
	"card_heal", "card_small_heal",
	"card_shield", "card_strength"
]

func _ready():
	_setup_player_panels()
	if multiplayer.is_server():
		for i in range(3):
			var chara = CHARACTER_bronya.instantiate()
			chara.name = "HostCharacter_%d" % i
			chara.set_multiplayer_authority(multiplayer.get_unique_id())
			chara.position = GlobalGameData.host_birth_point[i]
			Characters.add_child(chara)
		
		_init_player_card_systems()
		multiplayer.peer_connected.connect(_on_client_joined)
	else:
		pass

func _on_client_joined(id: int):
	print("[Info] 客户端 %d 加入，为其创建角色" % id)
	_init_player_card_systems()
	call_deferred("_deferred_spawn_client_characters", id)

func _deferred_spawn_client_characters(id: int):
	for i in range(3):
		var chara = CHARACTER_seele.instantiate()
		chara.name = "Client%dCharacter_%d" % [id, i]
		chara.set_multiplayer_authority(id)
		chara.position = GlobalGameData.client_birth_point[i]
		Characters.add_child(chara)
	print("[Info] 开始游戏")
	rpc("advance_turn_phase")

func _init_player_card_systems():
	if not multiplayer.is_server():
		return
	var host_id = multiplayer.get_unique_id()
	var player_ids: Array[int] = [host_id, 2]
	for pid in player_ids:
		deck_manager.init_player(pid, default_deck.duplicate())
	energy_system.init_players(player_ids)

func register_character(chara: CharacterBody2D):
	characters.append(chara)
	if chara.name.begins_with("Host"):
		GlobalGameData.host_characters.append(chara)
	elif chara.name.begins_with("Client"):
		GlobalGameData.client_characters.append(chara)

func unregister_character(chara: CharacterBody2D):
	characters.erase(chara)
	GlobalGameData.host_characters.erase(chara)
	GlobalGameData.client_characters.erase(chara)
	if selected_character == chara:
		if highlight_layer:
			highlight_layer.clear()
			
func select_character(chara: CharacterBody2D):
	if chara.name.begins_with("Host") != GlobalGameData.is_host:
		return
	if chara.hp <= 0:
		return
	if selected_character != null:
		selected_character.is_selected = false
		selected_character = null
		character_info_panel.hide()
	selected_character = chara
	chara.is_selected = true
	character_info_panel.show_for(chara)
	skill_panel.show_for(chara)

func unselect_character(chara: CharacterBody2D, unselect_all = false):
	if unselect_all:
		if selected_character != null:
			selected_character.is_selected = false
			selected_character = null
			character_info_panel.hide()
			skill_panel.hide()
	else:
		chara.is_selected = false
		selected_character = null
		character_info_panel.hide()
		skill_panel.hide()
	
func is_cell_occupied(cell: Vector2i, except_chara = null) -> bool:
	cell_occupancy.clear()
	for chara in characters:
		if not chara or not chara.grid_layer:
			continue
		var local_pos = chara.grid_layer.to_local(chara.global_position)
		cell_occupancy[chara.grid_layer.local_to_map(local_pos)] = chara
	if cell_occupancy.has(cell):
		var occupant = cell_occupancy[cell]
		if occupant != null and (except_chara == null or occupant != except_chara):
			return true
	return false
	
func find_cell_occupant(cell: Vector2i, except_chara = null) -> CharacterBody2D:
	cell_occupancy.clear()
	for chara in characters:
		if not chara or not chara.grid_layer:
			continue
		var local_pos = chara.grid_layer.to_local(chara.global_position)
		cell_occupancy[chara.grid_layer.local_to_map(local_pos)] = chara
	if cell_occupancy.has(cell):
		var occupant = cell_occupancy[cell]
		if occupant != null and (except_chara == null or occupant != except_chara):
			return occupant
	return null
	
func start_character_move():
	is_any_character_moving = true

func end_character_move():
	is_any_character_moving = false


# === 卡牌系统 ===

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_targeting:
			_try_select_target(event.position)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if not is_targeting:
		return
	if not is_targeting:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_targeting()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_select_target(event.position)
		get_viewport().set_input_as_handled()

func _try_select_target(_pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collision_mask = 2
	var results = space_state.intersect_point(query)
	for r in results:
		var hit = r.collider
		if hit is CharacterBody2D:
			_on_target_selected(hit)
			return
	cancel_targeting()

func on_card_played(card_data: CardData):
	var my_pid = 1 if GlobalGameData.is_host else 2
	var who = "Host" if GlobalGameData.is_host else "Client"
	if get_current_player_id() != my_pid:
		return
	if not energy_system.can_afford(my_pid, card_data.cost):
		print("[Warning] %s 能量不足，无法使用 %s" % [who, card_data.card_name])
		return
	print("[Info] %s 选中卡牌: %s" % [who, card_data.card_name])
	if card_data.target_type == CardData.TargetType.NONE:
		rpc("_server_play_card", my_pid, card_data.id, "")
	else:
		pending_card_data = card_data
		is_targeting = true
		highlight_targets(card_data)
		print("[Info] 请选择目标")

func highlight_targets(card_data: CardData):
	highlight_layer.clear()
	match card_data.target_type:
		CardData.TargetType.ALLY_SINGLE, CardData.TargetType.ALLY_ALL:
			var allies = _get_my_characters()
			for c in allies:
				if c.hp > 0:
					var cell = _get_character_cell(c)
					if cell != null:
						highlight_layer.set_cell(cell, 0, Vector2i.ZERO)
		CardData.TargetType.ENEMY_SINGLE, CardData.TargetType.ENEMY_ALL:
			var enemies = _get_enemy_characters()
			for c in enemies:
				if c.hp > 0:
					var cell = _get_character_cell(c)
					if cell != null:
						highlight_layer.set_cell(cell, 0, Vector2i.ZERO)
		CardData.TargetType.SELF:
			if selected_character and selected_character.hp > 0:
				var cell = _get_character_cell(selected_character)
				if cell != null:
					highlight_layer.set_cell(cell, 0, Vector2i.ZERO)

func on_card_dropped(card_data: CardData) -> bool:
	on_card_played(card_data)
	if is_targeting:
		var mouse_pos = get_global_mouse_position()
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collision_mask = 2
		var results = space_state.intersect_point(query)
		for r in results:
			var hit = r.collider
			if hit is CharacterBody2D and hit.hp > 0:
				var card = pending_card_data
				if card:
					var target_type = card.target_type
					var is_ally = _is_ally(hit)
					if _is_valid_target(target_type, is_ally):
						_on_target_selected(hit)
						return true
		cancel_targeting()
	return false

func _is_ally(chara: CharacterBody2D) -> bool:
	var is_host = chara.name.begins_with("Host")
	return is_host == GlobalGameData.is_host

func _is_valid_target(target_type: int, is_ally: bool) -> bool:
	match target_type:
		CardData.TargetType.SELF:
			return selected_character != null
		CardData.TargetType.ALLY_SINGLE, CardData.TargetType.ALLY_ALL:
			return is_ally
		CardData.TargetType.ENEMY_SINGLE, CardData.TargetType.ENEMY_ALL:
			return not is_ally
		CardData.TargetType.ALL_CHARACTERS:
			return true
		_:
			return false

func cancel_targeting():
	pending_card_data = null
	is_targeting = false
	highlight_layer.clear()
	if hand_panel:
		hand_panel.clear_selection()

func _on_target_selected(target: Node):
	if not is_targeting:
		return
	if pending_card_data:
		var card_data = pending_card_data
		var who = "Host" if GlobalGameData.is_host else "Client"
		print("[Info] %s 对 %s 释放 %s" % [who, target.name, card_data.card_name])
		_target_play_card(card_data, target)
		hand_panel.remove_card_via_data(card_data)
		cancel_targeting()
	elif selected_character and selected_character.has_method("use_active_skill") and selected_character.active_skill:
		selected_character.use_active_skill(target)
		selected_character.active_skill.cooldown = 3
		skill_panel._update_cooldown()
		cancel_targeting()

func _target_play_card(card_data: CardData, target: Node):
	var target_path = ""
	if target:
		target_path = target.get_path()
	var my_pid = 1 if GlobalGameData.is_host else 2
	if multiplayer.has_multiplayer_peer():
		rpc("_server_play_card", my_pid, card_data.id, target_path)
	else:
		_execute_play_card(my_pid, card_data.id, target_path)

@rpc("any_peer", "call_local", "reliable")
func _server_play_card(player_id: int, card_id: String, target_path: String):
	if not multiplayer.is_server():
		return
	_execute_play_card(player_id, card_id, target_path)

func _execute_play_card(player_id: int, card_id: String, target_path: String):
	var card_data = CardDatabase.get_card(card_id)
	if not card_data:
		return
	if not energy_system.spend_energy(player_id, card_data.cost):
		return
	if not deck_manager.play_card(player_id, card_id):
		energy_system.set_energy(player_id, energy_system.get_energy(player_id) + card_data.cost)
		return

	var target: Node = null
	if target_path and not target_path.is_empty():
		target = get_node_or_null(target_path)
	var caster: Node = null
	var who = "Host" if player_id == 1 else "Client"
	if player_id == 1:
		for c in GlobalGameData.host_characters:
			if c.hp > 0:
				caster = c
				break
	else:
		for c in GlobalGameData.client_characters:
			if c.hp > 0:
				caster = c
				break

	print("[Info] %s 释放 %s，目标: %s，施法者: %s" % [who, card_data.card_name, target.name if target else "无", caster.name if caster else "无"])

	CardEffect.execute(card_data, caster, target, self)
	var hand = deck_manager.get_hand(player_id)
	var energy = energy_system.get_energy(player_id)
	if multiplayer.has_multiplayer_peer():
		rpc("_sync_card_play", player_id, card_id, target_path)
		rpc("_sync_energy", player_id, energy)
		rpc("_sync_hand", player_id, hand)
	_sync_hand(player_id, hand)
	_sync_energy(player_id, energy)

@rpc("call_local", "reliable")
func _sync_card_play(_player_id: int, _card_id: String, _target_path: String):
	pass

@rpc("call_local", "reliable")
func _sync_energy(player_id: int, value: int):
	energy_system.player_energy[player_id] = value
	_update_player_panels()

@rpc("call_local", "reliable")
func _sync_hand(player_id: int, hand: Array):
	var my_pid = 1 if GlobalGameData.is_host else 2
	if player_id == my_pid:
		var typed: Array[String] = []
		typed.assign(hand)
		hand_panel.set_hand(typed)

func _on_skill_used(skill: BaseSkill, target_type: int):
	if not selected_character or not skill:
		return
	match target_type:
		BaseSkill.SkillTarget.NONE, BaseSkill.SkillTarget.SELF:
			selected_character.use_active_skill(selected_character)
		BaseSkill.SkillTarget.ALLY_SINGLE:
			pending_card_data = null
			is_targeting = true
			highlight_skill_targets()
		BaseSkill.SkillTarget.ENEMY_SINGLE:
			pending_card_data = null
			is_targeting = true
			highlight_skill_targets()

func highlight_skill_targets():
	highlight_layer.clear()
	if not selected_character:
		return
	var skill = selected_character.active_skill
	if not skill:
		return
	match skill.target_type:
		BaseSkill.SkillTarget.ALLY_SINGLE:
			for c in _get_my_characters():
				if c.hp > 0:
					highlight_layer.set_cell(_get_character_cell(c), 0, Vector2i.ZERO)
		BaseSkill.SkillTarget.ENEMY_SINGLE:
			for c in _get_enemy_characters():
				if c.hp > 0:
					highlight_layer.set_cell(_get_character_cell(c), 0, Vector2i.ZERO)

func _update_player_energy():
	_update_player_panels()

func draw_extra_card(caster: Node):
	if not multiplayer.is_server():
		return
	var pid = 1 if caster in GlobalGameData.host_characters else 2
	deck_manager.draw_cards(pid, 1)

func _get_my_characters() -> Array:
	if GlobalGameData.is_host:
		return GlobalGameData.host_characters
	else:
		return GlobalGameData.client_characters

func _get_enemy_characters() -> Array:
	if GlobalGameData.is_host:
		return GlobalGameData.client_characters
	else:
		return GlobalGameData.host_characters

func _get_character_cell(chara: Node) -> Vector2i:
	if not chara or not chara.grid_layer:
		return Vector2i(-1, -1)
	var local_pos = chara.grid_layer.to_local(chara.global_position)
	return chara.grid_layer.local_to_map(local_pos)

func get_current_player_id() -> int:
	var phase = GlobalGameData.current_turn_phase
	match phase:
		GlobalGameData.TurnPhase.PLAYER_MOVE, GlobalGameData.TurnPhase.PLAYER_ATTACK:
			return 1 if GlobalGameData.is_host_turn else 2
		GlobalGameData.TurnPhase.ENEMY_MOVE, GlobalGameData.TurnPhase.ENEMY_ATTACK:
			return 2 if GlobalGameData.is_host_turn else 1
	return -1


# === 回合系统 ===
@rpc("call_local", "reliable")
func start_new_round():
	if not multiplayer.is_server():
		return
	
	if not GlobalGameData.turn_has_been_drawn:
		GlobalGameData.is_host_turn = true if randi() % 2 else false
		if GlobalGameData.is_host_turn:
			print("[Info] 服务端先手")
		else:
			print("[Info] 客户端先手")
	
	rpc("reset_character_state")
	rpc("draw_for_new_turn")
	rpc("process_all_buffs")
	GlobalGameData.turn_has_been_drawn = true

	advance_turn_phase()

@rpc("call_local", "reliable")
func process_all_buffs():
	for chara in get_tree().get_nodes_in_group("characters"):
		if chara.has_method("process_buffs"):
			chara.process_buffs()

@rpc("call_local", "reliable")
func draw_for_new_turn():
	if not multiplayer.is_server():
		return
	if not GlobalGameData.turn_has_been_drawn:
		deck_manager.init_initial_draw(1)
		deck_manager.init_initial_draw(2)
		sync_all_card_state()
	else:
		deck_manager.draw_cards(1, 1)
		deck_manager.draw_cards(2, 1)
		energy_system.restore_energy(1)
		energy_system.restore_energy(2)
		sync_all_card_state()

func sync_all_card_state():
	for pid in [1, 2]:
		rpc_id(0, "_sync_energy", pid, energy_system.get_energy(pid))
		rpc_id(0, "_sync_hand", pid, deck_manager.get_hand(pid))

@rpc("any_peer", "call_local", "reliable")
func reset_character_state() -> void:
	GlobalGameData.character_move_used_num = 0
	GlobalGameData.character_move_used.clear()
	GlobalGameData.character_attack_used_num = 0
	GlobalGameData.character_attack_used.clear()
	for c in characters:
		GlobalGameData.character_move_used[c.name] = false
		GlobalGameData.character_attack_used[c.name] = false

@rpc("any_peer", "call_local", "reliable")
func advance_turn_phase():
	if not multiplayer.is_server():
		return
		
	if check_victory():
		print("[Info] 游戏结束")
		GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.GAME_OVER
		return
	
	match GlobalGameData.current_turn_phase:
		GlobalGameData.TurnPhase.NONE, GlobalGameData.TurnPhase.GAME_OVER:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.START_ROUND
			start_new_round()
		
		GlobalGameData.TurnPhase.START_ROUND:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.PLAYER_MOVE
		
		GlobalGameData.TurnPhase.PLAYER_MOVE:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.PLAYER_ATTACK
		
		GlobalGameData.TurnPhase.PLAYER_ATTACK:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.ENEMY_MOVE
		
		GlobalGameData.TurnPhase.ENEMY_MOVE:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.ENEMY_ATTACK
		
		GlobalGameData.TurnPhase.ENEMY_ATTACK:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.START_ROUND
			start_new_round()
	
	rpc_id(0, "_sync_turn_phase", GlobalGameData.current_turn_phase, GlobalGameData.is_host_turn)

@rpc("call_local", "reliable")
func _sync_turn_phase(phase: int, host_turn: bool = GlobalGameData.is_host_turn):
	GlobalGameData.current_turn_phase = phase
	GlobalGameData.is_host_turn = host_turn
	update_ui_turn_indicator()

func update_ui_turn_indicator():
	turn_indicator.update_turn_display()
	_update_player_panels()
	if hand_panel:
		hand_panel.clear_selection()

func _setup_player_panels():
	var is_local_host = GlobalGameData.is_host
	if is_local_host:
		host_player_panel.anchor_left = 1.0
		host_player_panel.anchor_top = 1.0
		host_player_panel.anchor_right = 1.0
		host_player_panel.anchor_bottom = 1.0
		host_player_panel.offset_left = -200.0
		host_player_panel.offset_top = -80.0
		host_player_panel.offset_right = -10.0
		host_player_panel.offset_bottom = -10.0
		client_player_panel.anchor_left = 1.0
		client_player_panel.anchor_top = 0.0
		client_player_panel.anchor_right = 1.0
		client_player_panel.anchor_bottom = 0.0
		client_player_panel.offset_left = -200.0
		client_player_panel.offset_top = 10.0
		client_player_panel.offset_right = -10.0
		client_player_panel.offset_bottom = 80.0
	else:
		client_player_panel.anchor_left = 1.0
		client_player_panel.anchor_top = 1.0
		client_player_panel.anchor_right = 1.0
		client_player_panel.anchor_bottom = 1.0
		client_player_panel.offset_left = -200.0
		client_player_panel.offset_top = -80.0
		client_player_panel.offset_right = -10.0
		client_player_panel.offset_bottom = -10.0
		host_player_panel.anchor_left = 1.0
		host_player_panel.anchor_top = 0.0
		host_player_panel.anchor_right = 1.0
		host_player_panel.anchor_bottom = 0.0
		host_player_panel.offset_left = -200.0
		host_player_panel.offset_top = 10.0
		host_player_panel.offset_right = -10.0
		host_player_panel.offset_bottom = 80.0

func _update_player_panels():
	if not energy_system:
		return
	if host_player_panel:
		var host_energy = energy_system.get_energy(1)
		var host_turn = _is_player_turn(true)
		host_player_panel.refresh(host_turn, host_energy)
	if client_player_panel:
		var client_energy = energy_system.get_energy(2)
		var client_turn = _is_player_turn(false)
		client_player_panel.refresh(client_turn, client_energy)

func _is_player_turn(check_host: bool) -> bool:
	var phase = GlobalGameData.current_turn_phase
	var is_host_turn = GlobalGameData.is_host_turn
	match phase:
		GlobalGameData.TurnPhase.PLAYER_MOVE, GlobalGameData.TurnPhase.PLAYER_ATTACK:
			return is_host_turn == check_host
		GlobalGameData.TurnPhase.ENEMY_MOVE, GlobalGameData.TurnPhase.ENEMY_ATTACK:
			return is_host_turn != check_host
	return false
	
func check_move() -> void:
	var my_count = 0
	for c in characters:
		if c.name.begins_with("Host") != GlobalGameData.is_host:
			continue
		my_count += 1
	if GlobalGameData.character_move_used_num >= my_count:
		GlobalGameData.character_move_used_num = 0
		print("[Info] 移动次数耗尽，进入下一阶段")
		rpc("advance_turn_phase")
		
func check_attack() -> void:
	var my_count = 0
	for c in characters:
		if c.name.begins_with("Host") != GlobalGameData.is_host:
			continue
		my_count += 1
	if GlobalGameData.character_attack_used_num >= my_count:
		GlobalGameData.character_attack_used_num = 0
		print("[Info] 攻击次数耗尽，进入下一阶段")
		rpc("advance_turn_phase")

func check_victory() -> bool:
	if GlobalGameData.host_characters.is_empty() or GlobalGameData.client_characters.is_empty():
		return false
	
	var host_alive = GlobalGameData.host_characters.any(func(c): return c.hp > 0)
	var client_alive = GlobalGameData.client_characters.any(func(c): return c.hp > 0)
	
	if not host_alive:
		print("[Info] 客户端玩家胜利")
		return true
	if not client_alive:
		print("[Info] 服务端玩家胜利")
		return true
	return false

func _update_character_info_panel(chara):
	if character_info_panel and character_info_panel.current_character == chara:
		character_info_panel.refresh()

func is_my_turn() -> bool:
	var phase = GlobalGameData.current_turn_phase
	match phase:
		GlobalGameData.TurnPhase.PLAYER_MOVE, GlobalGameData.TurnPhase.PLAYER_ATTACK:
			return GlobalGameData.is_host_turn == GlobalGameData.is_host
		GlobalGameData.TurnPhase.ENEMY_MOVE, GlobalGameData.TurnPhase.ENEMY_ATTACK:
			return GlobalGameData.is_host_turn != GlobalGameData.is_host
	return false
