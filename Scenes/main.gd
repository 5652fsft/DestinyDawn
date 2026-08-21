extends Node2D

func _log(msg: String, category: String = "AI"):
	print("[%s] %s" % [category, msg])


var selected_character = null
var characters: Array[CharacterBody2D] = []
var cell_occupancy: Dictionary = {}
var _reserved_cells: Dictionary = {}  # cell_coord -> character (移动中角色预占的格子)
var _refresh_panel_timer: float = 0.0
var is_any_character_moving: bool:
	get:
		return _move_counter > 0
var _move_counter: int = 0
var _move_timeout: float = 0.0
var is_move_mode: bool = false
var is_attack_mode: bool = false
var is_viewing_enemy: bool = false
var _hand_hidden: bool = false
var _hand_hidden_before_menu: bool = false
var _surrender_dialog: Panel = null
var _battle_over: bool = false
# 输入锁：回合过渡/投降菜单/战斗结算期间禁止棋盘点击（GUI 遮罩之外的代码级锁）
var is_input_locked: bool = false

# === 卡牌系统 ===
var pending_card_data: CardData = null
var is_targeting: bool = false
var current_card_player_id: int = -1
var _cell_targeting: bool = false
var _pending_skill: BaseSkill = null

@onready var ground_layer: TileMapLayer = $Map/Ground
@onready var highlight_layer: TileMapLayer = $Map/Highlight
@onready var Characters:Node2D = $Characters
@onready var character_info_panel = $UI/CharacterInfoPanel
@onready var turn_indicator = $UI/TurnIndicator
@onready var hand_panel = $UI/HandPanel
@onready var energy_system = $EnergySystem
@onready var deck_manager = $DeckManager
var buff_manager: Node = null
var vfx_manager: Node = null
var field_effect_manager: Node = null
var projectile_manager: Node = null
@onready var skill_panel = $UI/SkillPanel
@onready var move_button = $UI/MoveButton
@onready var attack_button = $UI/AttackButton
@onready var auto_battle_button = $UI/AutoBattleButton
var _auto_input_locked: bool = false
@onready var host_player_panel = $UI/HostPlayerPanel
@onready var client_player_panel = $UI/ClientPlayerPanel
@onready var toast = $UI/Toast

const CHARACTER_BRONYA = preload("res://Characters/Bronya/Bronya.tscn")
const CHARACTER_SEELE = preload("res://Characters/Seele/Seele.tscn")
const CHARACTER_ELAINA = preload("res://Characters/Elaina/Elaina.tscn")
const CHARACTER_FIREFLY = preload("res://Characters/Firefly/Firefly.tscn")
const CHARACTER_SILVERWOLF = preload("res://Characters/SilverWolf/SilverWolf.tscn")
const CHARACTER_HAMSTER = preload("res://Characters/Hamster/Hamster.tscn")
const CHARACTER_KARRIGAN = preload("res://Characters/Karrigan/Karrigan.tscn")
const CHARACTER_ZEPHYR = preload("res://Characters/Zephyr/Zephyr.tscn")
const CHARACTER_ANPAN = preload("res://Characters/Anpan/Anpan.tscn")
const CHARACTER_M1DORG = preload("res://Characters/M1DorG/M1DorG.tscn")
const CHARACTER_RICHARDOVO = preload("res://Characters/Richardovo/Richardovo.tscn")
const CHARACTER_ANJING = preload("res://Characters/Anjing/Anjing.tscn")

var team_roster: Array[PackedScene] = []
var enemy_roster: Array[PackedScene] = []
var default_deck: Array[String] = []

var last_attacker: Node = null
var skill_overlays: Array[Node] = []
# 已处理过加入流程的客户端 id（防止定时器+信号双路径重复生成角色）
var _joined_clients: Array[int] = []

var _am:
	get:
		return Engine.get_singleton("AudioManager")

var _waiting_overlay: Control = null
# 客户端"等待主机"期间的重同步重试（防主机在客户端就绪前发出的一次性 RPC 被丢弃）
var _client_sync_retry: Timer = null

func _build_team_from_selection():
	team_roster.clear()
	enemy_roster.clear()
	var map = {
		"bronya": CHARACTER_BRONYA, "seele": CHARACTER_SEELE,
		"elaina": CHARACTER_ELAINA, "firefly": CHARACTER_FIREFLY,
		"silverwolf": CHARACTER_SILVERWOLF, "hamster": CHARACTER_HAMSTER,
		"karrigan": CHARACTER_KARRIGAN, "zephyr": CHARACTER_ZEPHYR,
		"anpan": CHARACTER_ANPAN,
		"M1DorG": CHARACTER_M1DORG, "Richardovo": CHARACTER_RICHARDOVO,
		"anjing": CHARACTER_ANJING,
	}
	if not GlobalGameData.selected_team.is_empty():
		for cid in GlobalGameData.selected_team:
			if cid in map:
				team_roster.append(map[cid])
	if not GlobalGameData.client_team.is_empty():
		for cid in GlobalGameData.client_team:
			if cid in map:
				enemy_roster.append(map[cid])
	# 空编队时用默认
	if team_roster.is_empty():
		for cid in GlobalGameData.DEFAULT_TEAM:
			if cid in map:
				team_roster.append(map[cid])
	if enemy_roster.is_empty():
		for cid in GlobalGameData.DEFAULT_TEAM:
			if cid in map:
				enemy_roster.append(map[cid])

func _build_deck_from_selection():
	default_deck = GlobalGameData.selected_deck.duplicate()

func _generate_ai_team_and_deck():
	GlobalGameData.client_team = []
	GlobalGameData.client_team.assign(AITeamBuilder.build_ai_team())
	GlobalGameData.ai_deck = []
	GlobalGameData.ai_deck.assign(AITeamBuilder.build_ai_deck())

func _init_player_card_systems_ai():
	deck_manager.init_player(1, GlobalGameData.selected_deck.duplicate())
	deck_manager.init_player(2, GlobalGameData.ai_deck.duplicate())
	energy_system.init_players([1, 2] as Array[int])

func _setup_ai_controller():
	var ai = load("res://AI/AIController.gd").new()
	ai.name = "AIController"
	add_child(ai)
	_log("AI 控制器已创建并添加到场景", "Mode")

func _ready():
	# 防御：已挂 ENet peer 却残留 AI 模式（如其他入口漏重置），强制回到联机流程
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and GlobalGameData.is_ai_mode:
		print("[Net] 警告：联机状态下残留 is_ai_mode=true，已强制关闭")
		GlobalGameData.is_ai_mode = false
	BackgroundSingleton.enter_battle()
	GlobalGameData.reset_battle_state()
	GlobalGameData.load_defaults_if_empty()
	if _am:
		_am._apply_saved_volumes()
		_am.play_bgm_random()
	_init_buff_manager()
	_init_vfx_manager()
	_init_field_effect_manager()
	_init_projectile_manager()
	energy_system.energy_spent.connect(_grant_energy_luck)

	if GlobalGameData.is_ai_mode:
		_log("AI 模式初始化开始", "Mode")
		_generate_ai_team_and_deck()
		_build_team_from_selection()
		_build_deck_from_selection()
		_setup_player_panels()
		_log("AI 队伍: %s, AI 卡组: %s" % [GlobalGameData.client_team, GlobalGameData.ai_deck])
		for i in range(team_roster.size()):
			_spawn_character(team_roster[i].resource_path, "HostCharacter_%d" % i, 1, GlobalGameData.host_birth_point[i])
		for i in range(enemy_roster.size()):
			_spawn_character(enemy_roster[i].resource_path, "ClientCharacter_%d" % i, GlobalGameData.client_peer_id if GlobalGameData.client_peer_id > 1 else 2, GlobalGameData.client_birth_point[i])
		_init_player_card_systems_ai()
		_log("双方角色已生成，卡牌系统已初始化", "Mode")
		_setup_action_buttons()
		_setup_ai_controller()
		call_deferred("advance_turn_phase")
		return

	if not multiplayer.has_multiplayer_peer():
		GlobalGameData.is_host = true
	_build_team_from_selection()
	_build_deck_from_selection()
	_setup_player_panels()
	if multiplayer.is_server():
		for i in range(team_roster.size()):
			_spawn_character(team_roster[i].resource_path, "HostCharacter_%d" % i, multiplayer.get_unique_id(), GlobalGameData.host_birth_point[i])
		
		_init_player_card_systems()
		multiplayer.peer_connected.connect(_on_client_joined)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		if GlobalGameData.pending_client_id > 0:
			var cid = GlobalGameData.pending_client_id
			GlobalGameData.pending_client_id = -1
			GlobalGameData.client_peer_id = cid
			get_tree().create_timer(0.5).timeout.connect(func():
				_on_client_joined(cid)
			)
		# 兜底：若客户端连接早于本场景就绪（peer_connected 已错过、pending_client_id 未设置），
		# 直接枚举已连接 peer 补处理（_on_client_joined 幂等，防重复）
		for pid in multiplayer.get_peers():
			if pid != multiplayer.get_unique_id():
				_on_client_joined(pid)
		_show_waiting_overlay()
		if not multiplayer.has_multiplayer_peer():
			advance_turn_phase()
	else:
		_show_client_waiting()
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	_setup_action_buttons()
	# 联机自动战斗：本端开启时也创建 AI 控制器（is_ai_mode 分支已无条件创建）
	if GlobalGameData.auto_battle_self:
		_setup_ai_controller()

func _setup_action_buttons():
	for btn in [move_button, attack_button]:
		ButtonTheme.apply_battle(btn)
		ButtonTheme.set_font(btn, 18)
	move_button.text = "移动"
	attack_button.text = "普通攻击"
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	_setup_mobile_buttons()
	_setup_auto_battle_button()

# === 自动战斗按钮（双端+单机均显示） ===
func _setup_auto_battle_button():
	var btn = auto_battle_button
	if not btn is Button:
		return
	ButtonTheme.apply_icon_small(btn)
	btn.icon = preload("res://Assets/Icons/gamepad.png")
	btn.text = ""
	btn.expand_icon = true
	btn.tooltip_text = "自动战斗：AI 接管本端操作"
	btn.pressed.connect(_toggle_auto_battle)
	btn.show()

func _toggle_auto_battle():
	GlobalGameData.auto_battle_self = not GlobalGameData.auto_battle_self
	var on = GlobalGameData.auto_battle_self
	# 点亮反馈：金色高亮
	auto_battle_button.modulate = Color(1.5, 1.1, 0.3) if on else Color.WHITE
	auto_battle_button.tooltip_text = "自动战斗：关闭" if on else "自动战斗：AI 接管本端操作"
	print("[AutoBattle] 本端自动战斗: %s" % on)
	if on:
		# 联机/单机玩家方：开启时确保 AI 控制器存在（_ready 时可能未创建）
		if not get_node_or_null("AIController"):
			_setup_ai_controller()
		# 清理玩家残留操作（选中/选卡/移动/攻击模式），并锁定本端输入
		_cancel_move_mode()
		_cancel_attack_mode()
		if has_method("cancel_targeting"):
			cancel_targeting()
		unselect_character(null, true)
		_auto_input_locked = true
		_update_action_buttons(selected_character)
	else:
		_auto_input_locked = false
		_update_action_buttons(selected_character)

# === 移动端（Android）补充 UI ===
func _is_mobile() -> bool:
	return OS.has_feature("android")

func _setup_mobile_buttons():
	var hand_btn = get_node_or_null("UI/HandToggleButton")
	var menu_btn = get_node_or_null("UI/SurrenderMenuButton")
	if hand_btn is Button:
		ButtonTheme.apply_icon_small(hand_btn)
		hand_btn.icon = preload("res://Assets/Icons/hand.png")
		hand_btn.text = ""
		hand_btn.expand_icon = true
		# 手牌按钮：双端显示（与 F 键共用 _toggle_hand），展开时点亮
		hand_btn.pressed.connect(_toggle_hand)
		hand_btn.modulate = Color(1.5, 1.1, 0.3) if not _hand_hidden else Color.WHITE
		hand_btn.show()
	if menu_btn is Button:
		ButtonTheme.apply_icon_small(menu_btn)
		menu_btn.icon = preload("res://Assets/Icons/menu.png")
		menu_btn.text = ""
		menu_btn.expand_icon = true
		# 投降菜单按钮：双端显示（与 ESC 键共用 _toggle_surrender_menu）
		menu_btn.pressed.connect(_toggle_surrender_menu)
		menu_btn.show()
	_apply_safe_area()

# 刘海屏安全区：把边缘 UI 面板向内容区内侧收拢
func _apply_safe_area():
	var bridge = get_node_or_null("/root/TouchInputBridge")
	if not bridge or not bridge.has_method("get_content_safe_insets"):
		return
	var insets: Vector4 = bridge.get_content_safe_insets()
	if insets == Vector4.ZERO:
		return
	for btn in [move_button, attack_button]:
		if btn is Control:
			btn.offset_left += insets.x
			btn.offset_right += insets.x
	for btn in [get_node_or_null("UI/HandToggleButton"), get_node_or_null("UI/SurrenderMenuButton")]:
		if btn is Control:
			btn.offset_left += insets.z
			btn.offset_right += insets.z
	if client_player_panel is Control:
		client_player_panel.offset_left += insets.z
		client_player_panel.offset_right -= insets.z
	if host_player_panel is Control:
		host_player_panel.offset_right -= insets.z

# 全屏界面（投降菜单/结算等）打开时隐藏辅助按钮，避免悬空叠层。
# 手牌/投降/自动战斗三按钮双端+单机均显示。
func _set_mobile_buttons_visible(v: bool):
	for btn in [get_node_or_null("UI/HandToggleButton"),
			get_node_or_null("UI/SurrenderMenuButton"),
			get_node_or_null("UI/AutoBattleButton")]:
		if btn is Control:
			btn.visible = v

func _update_action_buttons(chara):
	if _auto_input_locked:
		move_button.disabled = true
		attack_button.disabled = true
		move_button.modulate = Color(1, 1, 1, 0.5)
		attack_button.modulate = Color(1, 1, 1, 0.5)
		return
	if not chara:
		return
	var is_active = chara.has_method("get_current_phase") and chara.get_current_phase() == "Active"
	move_button.disabled = not is_active or GlobalGameData.character_move_used.get(chara.name, false)
	move_button.modulate = Color(1, 1, 1, 0.5) if move_button.disabled else Color(1, 1, 1)
	var atk_used = GlobalGameData.character_attack_used.get(chara.name, false)
	var extra = chara._get_extra_attacks() if chara.has_method("_get_extra_attacks") else 0
	attack_button.disabled = not is_active or (atk_used and extra <= 0)
	attack_button.modulate = Color(1, 1, 1, 0.5) if attack_button.disabled else Color(1, 1, 1)

# 额外行动/行动状态变化时刷新选中角色 UI（由 _sync_extra_attacks 等广播触发）
func refresh_character_ui(chara):
	if not chara:
		return
	if selected_character == chara:
		character_info_panel.refresh()
		_update_action_buttons(chara)

func _on_move_pressed():
	if not selected_character:
		print("[Warn] 移动按钮：selected_character 为空")
		return
	if _am: _am.play_sfx("click")
	if selected_character.get_current_phase() != "Active":
		print("[Warn] 移动按钮：不在行动回合")
		return
	if GlobalGameData.character_move_used.get(selected_character.name, false):
		show_toast("该角色本回合已移动")
		return
	if is_move_mode:
		_cancel_move_mode()
		return
	is_attack_mode = false
	_reset_button_texts()
	is_move_mode = true
	move_button.text = "取消移动"
	selected_character.hide_attack_range()
	selected_character.show_move_range()
	show_toast("点击格子移动")
	print("[Input] 进入移动模式")

func _on_attack_pressed():
	if not selected_character:
		print("[Warn] 攻击按钮：selected_character 为空")
		return
	if _am: _am.play_sfx("click")
	if selected_character.get_current_phase() != "Active":
		print("[Warn] 攻击按钮：不在行动回合")
		return
	if GlobalGameData.character_attack_used.get(selected_character.name, false):
		var extra = selected_character._get_extra_attacks() if selected_character.has_method("_get_extra_attacks") else 0
		if extra <= 0:
			show_toast("该角色本回合已行动")
			return
	if is_attack_mode:
		_cancel_attack_mode()
		return
	is_move_mode = false
	_reset_button_texts()
	is_attack_mode = true
	attack_button.text = "取消攻击"
	selected_character.hide_move_range()
	selected_character.show_attack_range()
	show_toast("点击敌人攻击")
	print("[Input] 进入攻击模式")

func _cancel_move_mode():
	is_move_mode = false
	_reset_button_texts()
	if selected_character and selected_character.has_method("hide_move_range"):
		selected_character.hide_move_range()
	show_toast("")

func _cancel_attack_mode():
	is_attack_mode = false
	_reset_button_texts()
	if selected_character and selected_character.has_method("hide_attack_range"):
		selected_character.hide_attack_range()
	show_toast("")

func _reset_button_texts():
	move_button.text = "移动"
	attack_button.text = "普通攻击"

func _spawn_character(scene_path: String, char_name: String, authority: int, pos: Vector2):
	var scene = load(scene_path)
	if not scene:
		return
	var chara = scene.instantiate()
	chara.name = char_name
	chara.owner_pid = authority
	chara.set_multiplayer_authority(authority)
	chara.position = pos
	Characters.add_child(chara)

# 联机编队/卡组同步
@rpc("any_peer", "reliable")
func _sync_host_setup(team_ids: Array, deck_ids: Array):
	GlobalGameData.host_team = team_ids
	GlobalGameData.selected_deck = deck_ids

# ==================== ready 阶段（开局同步） ====================
# 流程：客户端 _client_send_setup → 主机构建完整初始快照（双方角色定义）
#      → 广播 _sync_initial_snapshot → 双端按快照生成角色（幂等）
#      → 客户端回执 _client_ready → 主机全部就绪（或 5s 超时兜底）后开局
# 快照重发幂等：延迟进场的客户端经 _client_request_state 重同步补全角色（覆盖根因 B）

# 客户端就绪回执表（pid -> bool）
var _battle_ready_clients: Dictionary = {}
# ready 超时兜底已启动标记（防重复计时器）
var _battle_ready_timer_started: bool = false

@rpc("any_peer", "reliable")
func _client_send_setup(team_ids: Array, deck_ids: Array):
	var sender_id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or sender_id <= 0:
		return
	GlobalGameData.client_team = team_ids
	if deck_manager and not deck_ids.is_empty() and GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.NONE:
		deck_manager.init_player(sender_id, deck_ids)
	_build_team_from_selection()
	var snap = _build_initial_snapshot(sender_id)
	# 主机本地生成（幂等：已存在同名角色则跳过）
	_spawn_characters_from_snapshot(snap)
	# 广播快照给客户端（含主机角色与客户端角色，一次到位）
	rpc("_sync_initial_snapshot", snap.host, snap.client)
	_hide_waiting_overlay()
	print("[Net] 已广播初始快照（host=%d client=%d）" % [snap.host.size(), snap.client.size()])
	_start_ready_timeout()

# 构建开局快照：双方角色定义（场景路径/名字/owner_pid/出生点）
func _build_initial_snapshot(cid: int) -> Dictionary:
	var snap = {"host": [], "client": []}
	var host_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for i in range(team_roster.size()):
		snap.host.append({
			"scene": team_roster[i].resource_path,
			"name": "HostCharacter_%d" % i,
			"pid": host_id,
			"pos": GlobalGameData.host_birth_point[i],
		})
	for i in range(enemy_roster.size()):
		snap.client.append({
			"scene": enemy_roster[i].resource_path,
			"name": "ClientCharacter_%d" % i,
			"pid": cid,
			"pos": GlobalGameData.client_birth_point[i],
		})
	return snap

# 按快照生成角色（幂等：同名角色已存在则跳过，快照重发安全）
func _spawn_characters_from_snapshot(snap: Dictionary) -> void:
	var existing := {}
	for c in characters:
		existing[c.name] = true
	for entry in snap.get("host", []) + snap.get("client", []):
		if existing.has(entry.name):
			continue
		_spawn_character(entry.scene, entry.name, entry.pid, entry.pos)
		existing[entry.name] = true

# 客户端：接收初始快照，生成全部角色后回执就绪
@rpc("any_peer", "reliable")
func _sync_initial_snapshot(host_chars: Array, client_chars: Array):
	if multiplayer.is_server():
		return
	_spawn_characters_from_snapshot({"host": host_chars, "client": client_chars})
	if multiplayer.has_multiplayer_peer():
		rpc_id(1, "_client_ready")
		print("[Net] 客户端已按快照生成角色并回执 ready")

# 客户端就绪回执（服务端权威处理）
@rpc("any_peer", "reliable")
func _client_ready():
	var id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or id <= 0:
		return
	_battle_ready_clients[id] = true
	print("[Net] 客户端 %d 就绪" % id)
	_try_start_battle()

# 开局栅栏：全部已加入客户端就绪后推进回合
func _try_start_battle():
	if not multiplayer.is_server():
		return
	for pid in multiplayer.get_peers():
		if not _battle_ready_clients.has(pid):
			return
	if GlobalGameData.current_turn_phase != GlobalGameData.TurnPhase.NONE:
		return
	print("[Net] 全部客户端就绪，开局")
	advance_turn_phase()

# ready 超时兜底：客户端异常（快照丢失/回执丢失）时 5 秒后仍开局，避免卡死
func _start_ready_timeout():
	if _battle_ready_timer_started:
		return
	_battle_ready_timer_started = true
	get_tree().create_timer(5.0).timeout.connect(func():
		if not _battle_over and GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.NONE:
			print("[Net] ready 等待超时，兜底开局")
			advance_turn_phase()
	)

# setup 等待超时：客户端连接后迟迟不响应 _client_send_setup（卡在加载/异常）
# 时 30s 后按"客户端未就绪"结算，避免主机无限等待（移动端极端加载慢也不会误伤）
func _start_setup_timeout():
	get_tree().create_timer(30.0).timeout.connect(func():
		if _battle_over or GlobalGameData.current_turn_phase != GlobalGameData.TurnPhase.NONE:
			return
		if multiplayer.get_peers().is_empty():
			return
		print("[Net] setup 等待超时（客户端未上报编队），按投降结算")
		show_battle_result(true, false)
	)

func _init_buff_manager():
	var bm = Node.new()
	bm.name = "BuffManager"
	bm.set_script(load("res://Global/BuffManager.gd"))
	add_child(bm)
	buff_manager = bm

func _init_vfx_manager():
	var vm = Node.new()
	vm.name = "VFXManager"
	vm.set_script(load("res://Global/VFXManager.gd"))
	add_child(vm)
	vfx_manager = vm

func _init_field_effect_manager():
	var fm = Node2D.new()
	fm.name = "FieldEffectManager"
	fm.set_script(load("res://Global/FieldEffectManager.gd"))
	add_child(fm)
	field_effect_manager = fm

func _init_projectile_manager():
	var pm = Node.new()
	pm.name = "ProjectileManager"
	pm.set_script(load("res://Effects/ProjectileManager.gd"))
	add_child(pm)
	projectile_manager = pm

func _on_client_joined(id: int):
	if _joined_clients.has(id):
		return  # 幂等：定时器与 peer_connected 双路径只处理一次
	_joined_clients.append(id)
	print("[Net] 客户端 %d 加入" % id)
	GlobalGameData.client_peer_id = id
	rpc_id(id, "_sync_client_peer_id", id)
	rpc_id(id, "_sync_opponent_name", GlobalGameData.player_name)
	rpc_id(id, "_request_client_setup")
	_build_team_from_selection()
	_build_deck_from_selection()
	_init_player_card_systems()
	# 角色生成统一走 ready 阶段快照（_client_send_setup → _sync_initial_snapshot），此处不再逐条广播
	# 客户端迟迟不响应编队上报（卡在加载/异常）时 30s 后按未就绪结算，避免无限等待
	_start_setup_timeout()

# 断连处理：任意一方掉线均按对方投降结算（服务端与客户端对称）
func _on_peer_disconnected(id: int):
	if _battle_over:
		return
	if multiplayer.is_server():
		if id != GlobalGameData.client_peer_id:
			return
		print("[Net] 客户端 %d 断线，判定其投降" % id)
		for c in GlobalGameData.client_characters.duplicate():
			if is_instance_valid(c):
				c.hp = 0
				c.hide()
				c.collision_layer = 0
		show_battle_result(true, false)
	else:
		# 客户端视角：主机断线 → 判定主机投降，本端获胜结算（与主机判客户端投降对称）
		print("[Net] 服务端断开连接，判定其投降")
		for c in GlobalGameData.host_characters.duplicate():
			if is_instance_valid(c):
				c.hp = 0
				c.hide()
				c.collision_layer = 0
		show_battle_result(true, true)

@rpc("any_peer", "reliable")
func _sync_opponent_name(name: String):
	_hide_waiting_overlay()
	GlobalGameData.opponent_name = name
	print("[Net] 对方名称: %s" % name)
	# 同步链路已建立，停止重同步重试
	if _client_sync_retry:
		_client_sync_retry.stop()
		_client_sync_retry.queue_free()
		_client_sync_retry = null
	# 刷新玩家面板名称
	for p in [$UI/HostPlayerPanel, $UI/ClientPlayerPanel]:
		if p and p.has_method("refresh_name"):
			p.refresh_name()

@rpc("authority", "call_local", "reliable")
func _sync_client_peer_id(id: int):
	GlobalGameData.client_peer_id = id
	print("[Net] 客户端 peer ID: ", id)

# 客户端"等待主机"期间的周期重同步请求：主机首次同步 RPC 可能因客户端场景未就绪被丢弃，
# 客户端主动请求后由主机幂等补发（见 _client_request_state）
func _client_request_sync_tick():
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		rpc_id(1, "_client_request_state")

# 服务端处理：客户端请求重同步（幂等补发关键同步，避免客户端永久卡在"等待主机"）
@rpc("any_peer", "reliable")
func _client_request_state():
	var id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or id <= 0:
		return
	if _joined_clients.has(id):
		GlobalGameData.client_peer_id = id
		rpc_id(id, "_sync_client_peer_id", id)
		rpc_id(id, "_sync_opponent_name", GlobalGameData.player_name)
		rpc_id(id, "_request_client_setup")
		# 客户端会再次 _client_send_setup → 主机幂等重发初始快照，
		# 延迟进场的客户端可补全全部角色（含主机角色），覆盖"首次同步 RPC 丢失"竞态
	else:
		_on_client_joined(id)

@rpc("any_peer", "reliable")
func _request_client_setup():
	rpc_id(1, "_sync_opponent_name", GlobalGameData.player_name)
	rpc_id(1, "_client_send_setup", GlobalGameData.selected_team, GlobalGameData.selected_deck)

func _init_player_card_systems():
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	var host_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if GlobalGameData.pending_client_id > 0:
		GlobalGameData.client_peer_id = GlobalGameData.pending_client_id
	var player_ids: Array[int] = [host_id, GlobalGameData.client_peer_id]
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
	if _battle_over:
		if multiplayer.is_server():
			print("[AttackDebug] unregister skip battle_over char=", chara.name)
		return
	characters.erase(chara)
	GlobalGameData.host_characters.erase(chara)
	GlobalGameData.client_characters.erase(chara)
	if multiplayer.is_server():
		print("[AttackDebug] unregister char=", chara.name, " host_remaining=", _count_alive(GlobalGameData.host_characters), " client_remaining=", _count_alive(GlobalGameData.client_characters))
	if selected_character == chara:
		if highlight_layer:
			highlight_layer.clear()
	if check_victory():
		if GlobalGameData.is_ai_mode or multiplayer.is_server():
			if multiplayer.has_multiplayer_peer():
				rpc("advance_turn_phase")
			else:
				advance_turn_phase()

func select_character(chara: CharacterBody2D, enemy_view: bool = false):
	if chara.hp <= 0:
		return
	if not enemy_view and chara.name.begins_with("Host") != GlobalGameData.is_host:
		return
	if selected_character != null:
		selected_character.is_selected = false
		selected_character = null
		character_info_panel.hide()
		is_move_mode = false
		is_attack_mode = false
		_reset_button_texts()
	selected_character = chara
	is_viewing_enemy = enemy_view
	chara.is_selected = true
	if _am: _am.play_sfx("click")
	character_info_panel.show_for(chara)
	move_button.visible = not enemy_view
	attack_button.visible = not enemy_view
	_update_action_buttons(chara)
	if enemy_view:
		skill_panel.hide()
	else:
		skill_panel.show_for(chara)

func unselect_character(chara: CharacterBody2D, unselect_all = false):
	if unselect_all:
		if selected_character != null:
			selected_character.is_selected = false
			selected_character = null
		is_move_mode = false
		is_attack_mode = false
		_reset_button_texts()
		is_viewing_enemy = false
		character_info_panel.hide()
		skill_panel.hide()
		move_button.hide()
		attack_button.hide()
	else:
		chara.is_selected = false
		selected_character = null
		is_move_mode = false
		is_attack_mode = false
		_reset_button_texts()
		is_viewing_enemy = false
		character_info_panel.hide()
		skill_panel.hide()
		move_button.hide()
		attack_button.hide()
	
func reserve_move_cell(character: Node, cell: Vector2i):
	_reserved_cells[cell] = character

func unreserve_move_cell(character: Node):
	var keys = _reserved_cells.keys()
	for k in keys:
		if _reserved_cells[k] == character:
			_reserved_cells.erase(k)

func is_cell_occupied(cell: Vector2i, except_chara = null) -> bool:
	# 检查预占格子（移动中的角色）
	if _reserved_cells.has(cell):
		var occupant = _reserved_cells[cell]
		if except_chara == null or occupant != except_chara:
			return true
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
	
func show_toast(msg: String, duration: float = 1.5):
	if toast and toast.has_method("show_message"):
		toast.show_message(msg, duration)

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
	_move_counter += 1
	_move_timeout = 0.0

func end_character_move():
	_move_counter = max(0, _move_counter - 1)
	_move_timeout = 0.0

func _process(delta):
	if _move_counter > 0:
		_move_timeout += delta
		if _move_timeout > 10.0:
			_move_counter = 0
			_move_timeout = 0.0
			print("[Safety] 移动计数器超时，已自动重置")
	# 属性面板定时刷新（5次/秒）
	_refresh_panel_timer += delta
	if _refresh_panel_timer >= 0.2 and selected_character and character_info_panel and character_info_panel.current_character == selected_character:
		_refresh_panel_timer = 0.0
		character_info_panel.refresh()


# === 卡牌系统 ===

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_input_locked:
			return
		if _cell_targeting:
			if _is_mouse_over_skill_button():
				return
			_try_select_cell()
			get_viewport().set_input_as_handled()
			return
		if is_targeting:
			if _is_mouse_over_skill_button():
				return
			_try_select_target(event.position)
			get_viewport().set_input_as_handled()
			return
		_try_select_character(event.position)
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		if not is_input_locked and not _battle_over:
			_toggle_hand()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		_toggle_surrender_menu()

func _try_select_cell():
	if not selected_character or not _pending_skill:
		cancel_targeting()
		return
	var mouse_pos = get_global_mouse_position()
	var local_pos = ground_layer.to_local(mouse_pos)
	var cell = ground_layer.local_to_map(local_pos)
	if ground_layer.get_cell_source_id(cell) == -1:
		show_toast("无效目标位置")
		return
	# 创建临时标记节点传递格子坐标
	var marker = Node2D.new()
	Characters.add_child(marker)
	marker.global_position = ground_layer.to_global(ground_layer.map_to_local(cell))
	if multiplayer.has_multiplayer_peer():
		rpc("_server_execute_skill", selected_character.get_path(), "", marker.global_position)
		marker.queue_free()
		cancel_targeting()
		return
	var ok = selected_character.use_active_skill(marker)
	marker.queue_free()
	if not ok:
		show_toast("技能释放失败")
		cancel_targeting()
		return
	_active_skill_post_exec(_pending_skill)
	cancel_targeting()

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

func _try_select_character(_pos: Vector2):
	if is_targeting or is_move_mode or is_attack_mode:
		return
	if GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.GAME_OVER:
		return
	var ctrl = get_viewport().gui_get_hovered_control()
	while ctrl:
		if ctrl is BaseButton:
			return
		ctrl = ctrl.get_parent()
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collision_mask = 2
	var results = space_state.intersect_point(query)
	var clicked_ally = null
	var clicked_enemy = null
	for r in results:
		var hit = r.collider
		if hit is CharacterBody2D and hit.hp > 0:
			if _is_ally(hit):
				clicked_ally = hit
			else:
				clicked_enemy = hit
			break
	if clicked_ally:
		if clicked_ally.is_selected:
			unselect_character(clicked_ally, true)
		else:
			select_character(clicked_ally)
	elif clicked_enemy:
		if clicked_enemy.is_selected:
			unselect_character(clicked_enemy, true)
		else:
			select_character(clicked_enemy, true)
	elif selected_character:
		unselect_character(selected_character, true)

func _is_mouse_over_skill_button() -> bool:
	if not skill_panel:
		return false
	var use_button = skill_panel.get_node_or_null("VBoxContainer/UseButton")
	if not use_button:
		return false
	var ctrl = get_viewport().gui_get_hovered_control()
	while ctrl:
		if ctrl == use_button:
			return true
		ctrl = ctrl.get_parent()
	return false

func _my_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else (1 if GlobalGameData.is_host else 2)

func on_card_played(card_data: CardData):
	var my_pid = _my_id()
	var who_label = GlobalGameData.get_char_label(selected_character) if selected_character else GlobalGameData.player_name
	if get_current_player_id() != my_pid:
		return
	if not energy_system.can_afford(my_pid, card_data.cost):
		show_toast("能量不足！需要 %d 能量" % card_data.cost)
		print("[Warn] %s 能量不足，无法使用 %s" % [who_label, card_data.card_name])
		return
	if card_data.target_type == CardData.TargetType.NONE:
		if multiplayer.has_multiplayer_peer():
			rpc("_server_play_card", my_pid, card_data.id, "")
		else:
			_execute_play_card(my_pid, card_data.id, "")
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
					if _is_valid_target(target_type, is_ally, hit):
						_on_target_selected(hit)
						return true
		cancel_targeting()
	return false

func _is_ally(chara: CharacterBody2D) -> bool:
	var is_host = chara.name.begins_with("Host")
	return is_host == GlobalGameData.is_host

func _is_valid_target(target_type: int, is_ally: bool, hit: Node = null) -> bool:
	match target_type:
		CardData.TargetType.ALLY_SINGLE, CardData.TargetType.ALLY_ALL:
			return is_ally
		CardData.TargetType.ENEMY_SINGLE, CardData.TargetType.ENEMY_ALL:
			return not is_ally
		CardData.TargetType.ALL_CHARACTERS:
			return true
		_:
			return false

func _update_skill_button():
	if skill_panel and skill_panel.has_method("set_targeting_mode"):
		skill_panel.set_targeting_mode(is_targeting or _cell_targeting)

func cancel_targeting():
	pending_card_data = null
	is_targeting = false
	_cell_targeting = false
	_pending_skill = null
	highlight_layer.clear()
	_clear_skill_overlays()
	_update_skill_button()
	if selected_character and is_attack_mode and selected_character.get_current_phase() == "Active" and not GlobalGameData.character_attack_used.get(selected_character.name, false):
		selected_character.show_attack_range()

func _on_target_selected(target: Node):
	if not is_targeting:
		return
	if pending_card_data:
		var card_data = pending_card_data
		if not _is_valid_target(card_data.target_type, _is_ally(target), target):
			show_toast("目标选择无效")
			cancel_targeting()
			return
		var who_label = GlobalGameData.get_char_label(selected_character) if selected_character else GlobalGameData.player_name
		print("[Info] %s 对 %s 使用 [%s]" % [who_label, GlobalGameData.get_char_label(target), card_data.card_name])
		_target_play_card(card_data, target)
		hand_panel.remove_card_via_data(card_data)
		cancel_targeting()
	elif selected_character and selected_character.has_method("use_active_skill") and selected_character.active_skill:
		var skill = selected_character.active_skill
		if not SkillEffect._is_valid_target_for_skill(selected_character, skill, target):
			show_toast("目标选择无效")
			cancel_targeting()
			return
		if multiplayer.has_multiplayer_peer():
			rpc("_server_execute_skill", selected_character.get_path(), target.get_path(), Vector2.ZERO)
			cancel_targeting()
			return
		if not selected_character.use_active_skill(target):
			show_toast("技能释放失败（超出范围或条件不满足）")
			cancel_targeting()
			return
		_active_skill_post_exec(skill)
		cancel_targeting()

func _target_play_card(card_data: CardData, target: Node):
	var target_path = ""
	if target:
		target_path = target.get_path()
	var my_pid = _my_id()
	if multiplayer.has_multiplayer_peer():
		rpc("_server_play_card", my_pid, card_data.id, target_path)
	else:
		_execute_play_card(my_pid, card_data.id, target_path)

@rpc("any_peer", "call_local", "reliable")
func _server_play_card(player_id: int, card_id: String, target_path: String):
	if not multiplayer.is_server():
		return
	# 防伪造玩家身份：远端发送者与请求 player_id 不符时校正为发送者
	var sender = multiplayer.get_remote_sender_id()
	if sender != 0 and player_id != sender:
		player_id = sender
	_execute_play_card(player_id, card_id, target_path)

# 技能效果统一在服务端执行（与出牌同构）：操作端 rpc 转发，服务端执行 SkillEffect + 广播状态同步
@rpc("any_peer", "call_local", "reliable")
func _server_execute_skill(character_path: String, target_path: String, cell_pos: Vector2):
	if not multiplayer.is_server():
		return
	var character = get_node_or_null(character_path)
	if not character or not "active_skill" in character or not character.active_skill:
		rpc("_sync_skill_failed", "技能状态无效")
		return
	var skill = character.active_skill
	if skill.current_cooldown > 0:
		rpc("_sync_skill_failed", "技能冷却中")
		return
	var consumes_attack = not character.has_method("_consumes_attack_on_skill") or character._consumes_attack_on_skill()
	if consumes_attack and GlobalGameData.character_attack_used.get(character.name, false) and character._get_extra_attacks() <= 0:
		rpc("_sync_skill_failed", "本回合行动次数已用尽")
		return
	var target: Node = null
	var marker: Node = null
	if target_path != "":
		target = get_node_or_null(target_path)
	elif skill.target_type == BaseSkill.SkillTarget.CELL:
		marker = Node2D.new()
		marker.name = "SkillTargetMarker"
		Characters.add_child(marker)
		marker.global_position = cell_pos
		target = marker
	var ok = character.use_active_skill(target)
	if marker:
		marker.queue_free()
	if not ok:
		rpc("_sync_skill_failed", "技能释放失败（超出范围或条件不满足）")
		return
	# 服务端逻辑：冷却 & 行动点消耗
	skill.current_cooldown = skill.cooldown
	if consumes_attack:
		GlobalGameData.character_attack_used[character.name] = true
		GlobalGameData.character_attack_used_num += 1
	# 同步手牌 / 能量（服务端权威数据）
	var pid = SkillEffect.get_character_pid(character)
	var hand = deck_manager.get_hand(pid) if deck_manager else []
	var energy = energy_system.get_energy(pid) if energy_system else 0
	rpc("_sync_hand", pid, hand)
	_sync_hand(pid, hand)
	rpc("_sync_energy", pid, energy)
	_sync_energy(pid, energy)
	# 广播技能结果状态到所有端
	rpc("_sync_skill_state", character_path, skill.cooldown, consumes_attack, skill.skill_name)

@rpc("call_local", "reliable")
func _sync_skill_state(character_path: String, cooldown: int, attack_consumed: bool, skill_name: String):
	var character = get_node_or_null(character_path)
	if character:
		if "active_skill" in character and character.active_skill:
			character.active_skill.current_cooldown = cooldown
		# 服务端已在 _server_execute_skill 计数，这里只给客户端计，避免双加
		if attack_consumed and not multiplayer.is_server():
			GlobalGameData.character_attack_used[character.name] = true
			GlobalGameData.character_attack_used_num += 1
		if selected_character == character:
			skill_panel._update_cooldown()
			character_info_panel.refresh()
			_update_action_buttons(character)
	_cancel_move_mode()
	_cancel_attack_mode()
	if selected_character and selected_character.has_method("hide_attack_range"):
		selected_character.hide_attack_range()
	show_toast("释放 [%s]" % skill_name, 1.0)
	check_attack()
	_update_player_panels()
	cancel_targeting()
	_update_skill_button()

@rpc("call_local", "reliable")
func _sync_skill_failed(reason: String):
	if multiplayer.is_server():
		return
	show_toast(reason)
	cancel_targeting()
	_update_skill_button()

func _execute_play_card(player_id: int, card_id: String, target_path: String):
	var card_data = CardDatabase.get_card(card_id)
	if not card_data:
		return
	if not energy_system.spend_energy(player_id, card_data.cost):
		return
	if not deck_manager.play_card(player_id, card_id):
		energy_system.set_energy(player_id, energy_system.get_energy(player_id) + card_data.cost)
		# 退款后同步，避免两端手牌/能量不一致
		var refund_hand = deck_manager.get_hand(player_id)
		var refund_energy = energy_system.get_energy(player_id)
		if multiplayer.has_multiplayer_peer():
			rpc("_sync_energy", player_id, refund_energy)
			rpc("_sync_hand", player_id, refund_hand)
		_sync_hand(player_id, refund_hand)
		_sync_energy(player_id, refund_energy)
		return

	current_card_player_id = player_id

	var target: Node = null
	if target_path and not target_path.is_empty():
		target = get_node_or_null(target_path)
	var who_label = GlobalGameData.player_name if player_id == _my_id() else GlobalGameData.opponent_name
	print("[Card] %s 使用 [%s]，目标: %s" % [who_label, card_data.card_name, GlobalGameData.get_char_label(target) if target else "无"])
	if _am: _am.play_sfx("card_play")

	# 战斗统计：记录卡牌使用
	var stat_key = "host_cards_played" if player_id == 1 else "client_cards_played"
	GlobalGameData.battle_stats[stat_key] += 1

	CardEffect.execute(card_data, target, self)

	current_card_player_id = -1

	# 出牌计数 & あんパン被动
	GlobalGameData.cards_played_this_turn += 1
	_check_anpan_passive(player_id)

	var hand = deck_manager.get_hand(player_id)
	var energy = energy_system.get_energy(player_id)
	if multiplayer.has_multiplayer_peer():
		rpc("_sync_energy", player_id, energy)
		rpc("_sync_hand", player_id, hand)
	_sync_hand(player_id, hand)
	_sync_energy(player_id, energy)

@rpc("call_local", "reliable")
func _sync_energy(player_id: int, value: int):
	energy_system.player_energy[player_id] = value
	_update_player_panels()
	# 刷新手牌可用性
	var my_pid = _my_id()
	if player_id == my_pid:
		hand_panel.refresh_affordability(value)

@rpc("call_local", "reliable")
func _sync_hand(player_id: int, hand: Array):
	# 同步手牌数据结构（服务端权威值；客户端据此刷新本地数据，
	# 供自动战斗等本地逻辑读取；仅显示本端手牌）
	if deck_manager:
		var typed: Array[String] = []
		typed.assign(hand)
		deck_manager.player_hands[player_id] = typed
	var my_pid = _my_id()
	if player_id == my_pid:
		var typed: Array[String] = []
		typed.assign(hand)
		hand_panel.play_draw_animation(typed)
		# 刷新手牌可用性
		var energy = energy_system.get_energy(my_pid)
		hand_panel.refresh_affordability(energy)
		if _am and GlobalGameData.turn_has_been_drawn:
			_am.play_sfx("card_play")

func _on_skill_used(skill: BaseSkill, target_type: int):
	if not selected_character or not skill:
		return
	_cancel_move_mode()
	_cancel_attack_mode()
	if selected_character.has_method("hide_attack_range"):
		selected_character.hide_attack_range()
	match target_type:
		BaseSkill.SkillTarget.NONE, BaseSkill.SkillTarget.SELF:
			if multiplayer.has_multiplayer_peer():
				rpc("_server_execute_skill", selected_character.get_path(), selected_character.get_path(), Vector2.ZERO)
				cancel_targeting()
				_update_skill_button()
				return
			if not selected_character.use_active_skill(selected_character):
				show_toast("技能释放失败")
				_update_skill_button()
				return
			_active_skill_post_exec(skill)
			_update_skill_button()
		BaseSkill.SkillTarget.ALLY_SINGLE, BaseSkill.SkillTarget.ENEMY_SINGLE:
			pending_card_data = null
			is_targeting = true
			_pending_skill = null
			highlight_skill_targets()
			_update_skill_button()
		BaseSkill.SkillTarget.CELL:
			pending_card_data = null
			is_targeting = false
			_cell_targeting = true
			_pending_skill = skill
			highlight_layer.clear()
			show_toast("点击地图上的格子释放技能", 2.0)
			_update_skill_button()

func _active_skill_post_exec(skill: BaseSkill):
	if not selected_character or not skill:
		return
	_cancel_move_mode()
	_cancel_attack_mode()
	if selected_character.active_skill:
		selected_character.active_skill.current_cooldown = selected_character.active_skill.cooldown
		if not selected_character.has_method("_consumes_attack_on_skill") or selected_character._consumes_attack_on_skill():
			GlobalGameData.character_attack_used[selected_character.name] = true
			GlobalGameData.character_attack_used_num += 1
	skill_panel._update_cooldown()
	if selected_character.has_method("hide_attack_range"):
		selected_character.hide_attack_range()
	show_toast("释放 [%s]" % skill.skill_name, 1.0)
	check_attack()
	_update_action_buttons(selected_character)
	character_info_panel.refresh()
	_update_player_panels()
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	var pid = SkillEffect.get_character_pid(selected_character)
	var hand = deck_manager.get_hand(pid) if deck_manager else []
	if multiplayer.has_multiplayer_peer():
		rpc("_sync_hand", pid, hand)
	else:
		_sync_hand(pid, hand)
	var energy = energy_system.get_energy(pid) if energy_system else 0
	_sync_energy(pid, energy)
	cancel_targeting()

func _make_hex_overlay(color: Color, r: float = HexUtils.HEX_RADIUS) -> Polygon2D:
	var hex = Polygon2D.new()
	var pts: PackedVector2Array = []
	for k in range(6):
		var a = deg_to_rad(60 * k - 30)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	hex.polygon = pts
	hex.color = color
	hex.z_index = 60
	return hex

func _clear_skill_overlays():
	for h in skill_overlays:
		if is_instance_valid(h):
			h.queue_free()
	skill_overlays.clear()

func highlight_skill_targets():
	_clear_skill_overlays()
	if not selected_character:
		return
	var skill = selected_character.active_skill
	if not skill:
		return
	var is_ally_target = skill.target_type == BaseSkill.SkillTarget.ALLY_SINGLE
	var targets = _get_my_characters() if is_ally_target else _get_enemy_characters()
	var hex_color = Color(0.2, 0.4, 1.0, 0.45) if is_ally_target else Color(1.0, 0.15, 0.15, 0.45)
	var char_cell = _get_character_cell(selected_character)
	var reachable = {} if skill.skill_range <= 0 else SkillEffect.get_cells_in_range(selected_character.grid_layer, char_cell, skill.skill_range)
	for c in targets:
		if c.hp <= 0:
			continue
		if skill.skill_range > 0:
			var c_cell = _get_character_cell(c)
			if not reachable.has(c_cell):
				continue
		var hex = _make_hex_overlay(hex_color, HexUtils.HEX_RADIUS)
		var spr = c.get_node_or_null("Sprite2D")
		if spr:
			spr.add_child(hex)
		else:
			c.add_child(hex)
		skill_overlays.append(hex)

func _update_player_energy():
	_update_player_panels()

func _grant_energy_luck(player_id: int, cost: int):
	if cost <= 0:
		return
	var allies = GlobalGameData.host_characters if player_id == 1 else GlobalGameData.client_characters
	var bm = get_node_or_null("BuffManager")
	for c in allies:
		if c and c.character_name == "Anjing" and c.hp > 0:
			if bm and bm.has_method("apply_buff"):
				var anjing_data = CharacterData.get_data("anjing")
				for i in range(cost):
					bm.apply_buff(c, "luck", anjing_data["passive_luck_value"], anjing_data["passive_luck_duration"], c)
			print("[Passive] Anjing [贪玩雀神] 消耗 %d 点能量，获得 %d 层[牌运]" % [cost, cost])
			return

func _check_anpan_passive(player_id: int):
	if GlobalGameData.cards_played_this_turn <= 0 or GlobalGameData.cards_played_this_turn % 2 != 0:
		return
	var allies = GlobalGameData.host_characters if player_id == 1 else GlobalGameData.client_characters
	for c in allies:
		if c and c.character_name == "あんパン" and c.hp > 0:
			deck_manager.draw_cards(player_id, 1)
			var hand = deck_manager.get_hand(player_id)
			var cur_energy = energy_system.get_energy(player_id)
			energy_system.set_energy(player_id, cur_energy + 1)
			# 手牌由调用方 _execute_play_card 统一广播，这里只刷新本地
			_sync_hand(player_id, hand)
			print("[Passive] あんパン [面包大家族] 触发: 抽1张 + 回1能量")
			break

func draw_extra_card(_chara: Node, count: int = 1):
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	var pid = get_current_player_id()
	if pid <= 0:
		return  # 阶段异常（START_ROUND/GAME_OVER）不补给，避免误发给主机
	deck_manager.draw_cards(pid, count)
	var hand = deck_manager.get_hand(pid) if deck_manager else []
	if multiplayer.has_multiplayer_peer():
		rpc("_sync_hand", pid, hand)
	else:
		_sync_hand(pid, hand)

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
	var cid = GlobalGameData.client_peer_id
	match phase:
		GlobalGameData.TurnPhase.PLAYER_TURN:
			return 1 if GlobalGameData.is_host_turn else cid
		GlobalGameData.TurnPhase.ENEMY_TURN:
			return cid if GlobalGameData.is_host_turn else 1
	return -1


# === 回合系统 ===
@rpc("call_local", "reliable")
# 新回合开始：抽牌、处理 Buff、触发回合开始效果
func start_new_round():
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	
	if not GlobalGameData.turn_has_been_drawn:
		GlobalGameData.is_host_turn = true if randi() % 2 else false
		if GlobalGameData.is_host_turn:
			print("[Phase] 服务端先手")
		else:
			print("[Phase] 客户端先手")
	
	GlobalGameData.battle_stats.turns_taken += 1
	
	if multiplayer.has_multiplayer_peer():
		rpc("reset_character_state")
		rpc("draw_for_new_turn")
		rpc("process_all_buffs")
	else:
		reset_character_state()
		draw_for_new_turn()
		process_all_buffs()
	GlobalGameData.turn_has_been_drawn = true

	process_turn_start()
	advance_turn_phase()

@rpc("call_local", "reliable")
# 所有角色减少 Buff 持续回合，移除过期 Buff；tick 结算仅服务端执行，避免联机双倍结算
func process_all_buffs():
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	for chara in get_tree().get_nodes_in_group("characters"):
		if chara.has_method("process_buffs"):
			chara.process_buffs()

@rpc("call_local", "reliable")
# 处理角色回合开始效果（M1DorG 离开/回归、Richardovo 闭麦等）
func process_turn_start():
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	for c in get_tree().get_nodes_in_group("characters"):
		if c.hp <= 0:
			continue
		if "_away_turns_left" in c and c._away_turns_left > 0:
			var is_my_team_host = c in GlobalGameData.host_characters
			if (GlobalGameData.is_host_turn == is_my_team_host) == (GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.ENEMY_TURN):
				continue
			c._away_turns_left -= 1
			if c.has_method("_sync_away_state") and c.multiplayer and c.multiplayer.has_multiplayer_peer():
				c.rpc("_sync_away_state", c._away_turns_left)
			if c.has_signal("buffs_changed"):
				c.buffs_changed.emit()
			if c._away_turns_left == 0:
				var team = GlobalGameData.host_characters if c in GlobalGameData.host_characters else GlobalGameData.client_characters
				for ally in team:
					if ally.hp > 0 and ally.hp < ally.max_hp:
						ally.take_damage(-(ally.max_hp - ally.hp))
				var spr = c.get_node_or_null("Sprite2D")
				if spr:
					spr.modulate = Color.WHITE
				print("[Skill] %s 回归，恢复全体友方生命值" % GlobalGameData.get_char_label(c))
		if c.has_method("on_turn_start"):
			c.on_turn_start()

@rpc("call_local", "reliable")
func draw_for_new_turn():
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		print("[Draw] 跳过：非服务器且非AI模式")
		return
	print("[Draw] 开始抽牌，turn_has_been_drawn=", GlobalGameData.turn_has_been_drawn, " cid=", GlobalGameData.client_peer_id)
	if not GlobalGameData.turn_has_been_drawn:
		deck_manager.init_initial_draw(1)
		deck_manager.init_initial_draw(GlobalGameData.client_peer_id)
		sync_all_card_state()
	else:
		deck_manager.draw_cards(1, 1)
		deck_manager.draw_cards(GlobalGameData.client_peer_id, 1)
		energy_system.restore_energy(1)
		energy_system.restore_energy(GlobalGameData.client_peer_id)
		sync_all_card_state()

# === 手牌 ===
# 统一设置手牌可见性与按钮点亮（静默模式不播音效/不弹提示）
func _set_hand_visible(show: bool, silent := false):
	_hand_hidden = not show
	hand_panel.visible = show
	var hand_btn = get_node_or_null("UI/HandToggleButton")
	if hand_btn is Button:
		hand_btn.modulate = Color(1.5, 1.1, 0.3) if show else Color.WHITE
	if not silent and _am: _am.play_sfx("deck_select")

func _hide_hand():
	_set_hand_visible(false, true)

# 收起/展开手牌（F 键与移动端按钮共用）
func _toggle_hand():
	if GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.GAME_OVER:
		return
	_set_hand_visible(_hand_hidden)
	if _hand_hidden:
		show_toast("卡牌已收起，按 F 恢复" if not _is_mobile() else "卡牌已收起，点击手牌按钮恢复", 2.0)
	else:
		show_toast("卡牌已展开，按 F 收起" if not _is_mobile() else "卡牌已展开，点击手牌按钮收起", 2.0)

# 投降菜单开关（ESC 与移动端按钮共用）
func _toggle_surrender_menu():
	if _battle_over:
		return
	if _surrender_dialog and _surrender_dialog.visible:
		_hide_surrender_dialog()
		return
	if is_input_locked:
		return
	_show_surrender_dialog()

# === 投降 ===
func _show_surrender_dialog():
	is_input_locked = true
	# 记忆打开前手牌状态（ESC/取消按钮关闭共用恢复，避免手牌丢失记忆状态）
	_hand_hidden_before_menu = _hand_hidden
	if not _hand_hidden:
		_hide_hand()
	if _surrender_dialog:
		_surrender_dialog.show()
		character_info_panel.hide()
		skill_panel.hide()
		move_button.hide()
		attack_button.hide()
		# 延迟到事件处理结束后再隐藏按钮，避免 pressed 回调链中移除命中控件导致 dialog 异常
		_set_mobile_buttons_visible.call_deferred(false)
		return
	_surrender_dialog = load("res://UI/SurrenderDialog.tscn").instantiate()
	$UI.add_child(_surrender_dialog)
	character_info_panel.hide()
	skill_panel.hide()
	move_button.hide()
	attack_button.hide()
	_set_mobile_buttons_visible.call_deferred(false)
	if _am: _am.play_sfx("click")

func _hide_surrender_dialog():
	if _surrender_dialog:
		_surrender_dialog.hide()
	is_input_locked = false
	if not _battle_over:
		_set_mobile_buttons_visible.call_deferred(true)
		# 恢复手牌记忆状态（打开时若展开则已隐藏，此处还原；按钮点亮同步）
		if _hand_hidden != _hand_hidden_before_menu:
			_set_hand_visible(not _hand_hidden_before_menu, true)

func _confirm_surrender():
	_hide_surrender_dialog()
	var targets = GlobalGameData.host_characters if GlobalGameData.is_host else GlobalGameData.client_characters
	for c in targets:
		if c and c.has_method("take_damage_safe"):
			c.take_damage_safe(9999)
		elif c.multiplayer and c.multiplayer.has_multiplayer_peer():
			c.rpc("take_damage", 9999)
		elif c:
			c.hp = 0
	if multiplayer.has_multiplayer_peer():
		rpc_id(0, "_sync_surrender", GlobalGameData.is_host, GlobalGameData.battle_stats)
	show_battle_result(true, GlobalGameData.is_host)

@rpc("any_peer", "call_local", "reliable")
func _sync_surrender(surrendering_is_host: bool, stats: Dictionary = {}):
	GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.GAME_OVER
	if not stats.is_empty():
		GlobalGameData.battle_stats = stats
	show_battle_result(true, surrendering_is_host)

func _show_waiting_overlay():
	if _waiting_overlay:
		return
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_waiting_overlay = _make_waiting_overlay("等待玩家连接...")

func _show_client_waiting():
	if _waiting_overlay:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return
	_waiting_overlay = _make_waiting_overlay("等待主机...")
	# 防时序竞态：主机首次同步 RPC 可能因客户端场景未就绪被丢弃，周期性请求重同步
	# （收到 _sync_opponent_name 即链路建立，停止重试）
	_client_sync_retry = Timer.new()
	_client_sync_retry.wait_time = 0.5
	_client_sync_retry.timeout.connect(_client_request_sync_tick)
	add_child(_client_sync_retry)
	_client_sync_retry.start()

func _hide_waiting_overlay():
	if _waiting_overlay:
		_waiting_overlay.queue_free()
		_waiting_overlay = null

func _make_waiting_overlay(text: String) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0.08, 0.08, 0.12, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$UI.add_child(overlay)
	var font = load("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1))
	overlay.add_child(label)
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -200
	label.offset_top = -75
	label.offset_right = 200
	label.offset_bottom = -5
	return overlay

func show_battle_result(from_surrender: bool = false, surrendering_is_host: bool = false):
	if _battle_over:
		return
	_battle_over = true
	is_input_locked = true
	var i_win
	if from_surrender:
		i_win = GlobalGameData.is_host != surrendering_is_host
		# 胜利方绝对语义（修正：原写法在客户端视角打印反了，仅日志误导，结算不受影响）
		var host_won = i_win == GlobalGameData.is_host
		print("[Phase] 投降，胜利方: %s" % ("服务端" if host_won else "客户端"))
	else:
		var is_host_win = GlobalGameData.host_characters.any(func(c): return c.hp > 0)
		i_win = is_host_win if GlobalGameData.is_host else not is_host_win
		print("[Phase] 胜利方: %s" % ("服务端" if is_host_win else "客户端"))
	if _am:
		_am.stop_bgm(0.5)
		_am.play_sfx("victory" if i_win else "defeat")
	hand_panel.hide()
	character_info_panel.hide()
	skill_panel.hide()
	move_button.hide()
	attack_button.hide()
	# 延迟隐藏：避免覆盖 _hide_surrender_dialog 排队的 call_deferred(true)，确保结算时按钮最终隐藏
	_set_mobile_buttons_visible.call_deferred(false)
	var is_multiplayer = multiplayer.has_multiplayer_peer()
	if $UI.has_node("BattleResult"):
		$UI/BattleResult.show_result(i_win, GlobalGameData.battle_stats, is_multiplayer)

func sync_all_card_state():
	for pid in [1, GlobalGameData.client_peer_id]:
		if multiplayer.has_multiplayer_peer():
			rpc_id(0, "_sync_energy", pid, energy_system.get_energy(pid))
			rpc_id(0, "_sync_hand", pid, deck_manager.get_hand(pid))
		else:
			_sync_energy(pid, energy_system.get_energy(pid))
			_sync_hand(pid, deck_manager.get_hand(pid))

@rpc("any_peer", "call_local", "reliable")
func reset_character_state() -> void:
	GlobalGameData.cards_played_this_turn = 0
	GlobalGameData.character_move_used_num = 0
	GlobalGameData.character_move_used.clear()
	GlobalGameData.character_attack_used_num = 0
	GlobalGameData.character_attack_used.clear()
	for c in characters:
		GlobalGameData.character_move_used[c.name] = false
		GlobalGameData.character_attack_used[c.name] = false
		if "_extra_attacks" in c:
			c._extra_attacks = 0
		if "_burn_armor_used" in c:
			c._burn_armor_used = false
		if "active_skill" in c and c.active_skill and c.active_skill.current_cooldown > 0:
			c.active_skill.current_cooldown -= 1

	# 老将·领袖气质：队伍含 karrigan（无论死活）→ 该阵营存活全员获得[拧绳]（永久，幂等补发，净化后可重补）
	if GlobalGameData.is_ai_mode or multiplayer.is_server():
		var rope_value = int(CharacterData.get_data("karrigan").get("passive_rope_value", 5))
		for side in [GlobalGameData.host_characters, GlobalGameData.client_characters]:
			var has_karrigan = false
			for c in side:
				if c.character_name == "karrigan":
					has_karrigan = true
					break
			if not has_karrigan:
				continue
			for c in side:
				if c.hp <= 0:
					continue
				if buff_manager and buff_manager.has_method("apply_buff"):
					buff_manager.apply_buff(c, "rope", rope_value, 999, c)

	# 烟雾递减
	if field_effect_manager and field_effect_manager.has_method("tick_smoke"):
		field_effect_manager.tick_smoke()

@rpc("any_peer", "call_local", "reliable")
func advance_turn_phase():
	if _battle_over:
		return
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	# 服务端校验：仅当前回合玩家可推进回合（防客户端越权/连点）
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != 0:
		var sender = multiplayer.get_remote_sender_id()
		var expected = get_current_player_id()
		if expected > 0 and sender != expected:
			print("[Warn] 拒绝非当前回合玩家 %d 推进回合" % sender)
			return
		
	if check_victory():
		print("[Phase] 游戏结束")
		GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.GAME_OVER
		if multiplayer.has_multiplayer_peer():
			rpc_id(0, "_sync_turn_phase", GlobalGameData.current_turn_phase, GlobalGameData.is_host_turn, GlobalGameData.battle_stats, GlobalGameData.turn_has_been_drawn)
		_sync_turn_phase(GlobalGameData.current_turn_phase, GlobalGameData.is_host_turn, GlobalGameData.battle_stats, GlobalGameData.turn_has_been_drawn)
		_battle_over = true
		return
	
	match GlobalGameData.current_turn_phase:
		GlobalGameData.TurnPhase.NONE, GlobalGameData.TurnPhase.GAME_OVER:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.START_ROUND
			start_new_round()
		
		GlobalGameData.TurnPhase.START_ROUND:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.PLAYER_TURN
		
		GlobalGameData.TurnPhase.PLAYER_TURN:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.ENEMY_TURN
			process_turn_start()
		
		GlobalGameData.TurnPhase.ENEMY_TURN:
			GlobalGameData.current_turn_phase = GlobalGameData.TurnPhase.START_ROUND
			start_new_round()
	
	if multiplayer.has_multiplayer_peer():
		rpc_id(0, "_sync_turn_phase", GlobalGameData.current_turn_phase, GlobalGameData.is_host_turn, GlobalGameData.battle_stats, GlobalGameData.turn_has_been_drawn)
	_sync_turn_phase(GlobalGameData.current_turn_phase, GlobalGameData.is_host_turn, GlobalGameData.battle_stats, GlobalGameData.turn_has_been_drawn)

@rpc("call_local", "reliable")
func _sync_turn_phase(phase: int, host_turn: bool = GlobalGameData.is_host_turn, stats: Dictionary = {}, drawn: bool = false):
	if _battle_over:
		return
	GlobalGameData.current_turn_phase = phase
	GlobalGameData.is_host_turn = host_turn
	if not stats.is_empty():
		GlobalGameData.battle_stats = stats
	GlobalGameData.turn_has_been_drawn = drawn
	if selected_character:
		selected_character.is_selected = false
		selected_character = null
		character_info_panel.hide()
		skill_panel.hide()
		move_button.hide()
		attack_button.hide()
	if phase == GlobalGameData.TurnPhase.GAME_OVER:
		show_battle_result()
		return
	if phase == GlobalGameData.TurnPhase.PLAYER_TURN or phase == GlobalGameData.TurnPhase.ENEMY_TURN:
		if _am: _am.play_sfx("turn_start")
	var is_enemy_phase = phase == GlobalGameData.TurnPhase.ENEMY_TURN
	var is_my_turn = (host_turn == GlobalGameData.is_host) != is_enemy_phase
	if is_my_turn and GlobalGameData.is_ai_mode:
		var ai = $AIController
		if ai and ai.has_method("_focus_on_player_characters"):
			ai._focus_on_player_characters()
	update_ui_turn_indicator()

func update_ui_turn_indicator():
	turn_indicator.update_turn_display()
	_update_player_panels()

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
		var client_energy = energy_system.get_energy(GlobalGameData.client_peer_id)
		var client_turn = _is_player_turn(false)
		client_player_panel.refresh(client_turn, client_energy)

func _is_player_turn(check_host: bool) -> bool:
	var phase = GlobalGameData.current_turn_phase
	var is_host_turn = GlobalGameData.is_host_turn
	match phase:
		GlobalGameData.TurnPhase.PLAYER_TURN:
			return is_host_turn == check_host
		GlobalGameData.TurnPhase.ENEMY_TURN:
			return is_host_turn != check_host
	return false
	
func check_move() -> void:
	var total_remaining = 0
	for c in characters:
		if c.name.begins_with("Host") != GlobalGameData.is_host:
			continue
		var used = GlobalGameData.character_move_used.get(c.name, false)
		total_remaining += 0 if used else 1
	if total_remaining <= 0:
		print("[Phase] 所有角色已移动，点击结束回合")
		
func check_attack() -> void:
	var total_remaining = 0
	for c in characters:
		if c.name.begins_with("Host") != GlobalGameData.is_host:
			continue
		var used = GlobalGameData.character_attack_used.get(c.name, false)
		var extra = c._get_extra_attacks() if c.has_method("_get_extra_attacks") else 0
		total_remaining += (0 if used else 1) + extra
	if total_remaining <= 0:
		print("[Phase] 所有角色行动次数已耗尽，点击结束回合")
		if toast and toast.has_method("show_message"):
			toast.show_message("所有角色行动次数已耗尽，点击结束回合", 2.0)

func _count_alive(side) -> int:
	var n = 0
	for c in side:
		if c.hp > 0:
			n += 1
	return n

func check_victory() -> bool:
	if not GlobalGameData.turn_has_been_drawn:
		return false
	
	var host_alive = false
	for c in GlobalGameData.host_characters:
		if c.hp > 0: host_alive = true; break
	var client_alive = false
	for c in GlobalGameData.client_characters:
		if c.hp > 0: client_alive = true; break
	
	if not host_alive:
		print("[Phase] 客户端玩家胜利")
		return true
	if not client_alive:
		print("[Phase] 服务端玩家胜利")
		return true
	return false

func _update_character_info_panel(chara):
	if character_info_panel and character_info_panel.current_character == chara:
		character_info_panel.refresh()
		skill_panel.update_passive(chara)
		_update_action_buttons(chara)

func is_my_turn() -> bool:
	var phase = GlobalGameData.current_turn_phase
	match phase:
		GlobalGameData.TurnPhase.PLAYER_TURN:
			return GlobalGameData.is_host_turn == GlobalGameData.is_host
		GlobalGameData.TurnPhase.ENEMY_TURN:
			return GlobalGameData.is_host_turn != GlobalGameData.is_host
	return false
