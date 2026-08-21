extends Node
## ============================================================
## 联机测试探针（--nettest=<role>:<scenario>）
## 用途：双进程真实 ENet 对局的自动化测试（开局同步 / 断线 / 投降 / 连续多局等），
## 收集双端日志，配合 tests/run_case.ps1 运行。
##
## 默认未挂载（不影响正常游戏）：需要复测时在 project.godot [autoload] 区取消注释：
##   NetTest="*res://tests/NetTest.gd"
## 运行：pwsh tests/run_case.ps1 -Scenario <场景>（见 tests/README.md）
## 日志：tests/logs/<scenario>_host.log / _client.log（运行产物，已 git 忽略）
##
## scenario:
##   s0     干净开局对照（两端无残留状态，自动战斗 AI 对 AI）
##   s1     host 端残留 is_ai_mode=true（模拟 host 刚打完单机）→ 用户场景 1
##   s1full host 先真实打一局单机自动战斗再开联机（完整用户路径复现）
##   s2     client 端残留 is_ai_mode=true（模拟 client 刚打完单机）→ 用户场景 2
##   s3     client 连接成功后延迟 4s 再进入战斗场景（重同步补全验证）
##   s4     client 开局 8s 后自杀（模拟中途掉线）→ host 应判投降结算
##   s5     client 连接成功后永不进场（不回执 ready）→ host 30s setup 超时按未就绪结算
##   s6     client 延迟 12s 进场（ready 超时兜底 + 重同步补全组合）
##   s7     client 开局 12s 后投降 → 双端结算一致
##   s8     双端连续打两局（打完回菜单再开，验证状态残留）
##   s9     延迟 8s 才开自动战斗（中途接管）
##   s11    host 开局 8s 后自杀（模拟中途掉线）→ client 判其投降、本端获胜结算
##   s12    host 先打一局联机 → 回菜单 → 再开一局单机（验证联机残留不影响单机）
##
## 退出码：0=正常对局结束 42=检测到卡死 43=总超时 44=连接创建失败 77=自杀（模拟掉线）
## ============================================================

var role := ""
var scenario := ""

var _time := 0.0
var _scene_path := ""
var _host_started := false
var _client_started := false
var _solo_phase := false      # s1full：正在打单机
var _auto_on := false
var _over_reported := false
var _games_played := 0        # s8：已完成的联机局数
var _was_in_battle := false   # 曾进入战斗场景（s11 掉线回菜单判定）
var _suicided := false        # 自杀已执行
var _surrender_done := false  # 投降已执行
var _mp_done := false         # s12：联机局已打完
var _solo_started := false    # s12：单机局已开始

# 场景参数（_apply_scenario 按 scenario 配置）
var _suicide_t := -1.0        # 开局后第 N 秒自杀（模拟掉线）
var _surrender_t := -1.0      # 开局后第 N 秒投降
var _auto_delay := 1.5        # 开局后第 N 秒开启自动战斗
var _join_delay := 4.0        # 连接成功后延迟 N 秒进战斗场景

var _battle_t := 0.0
var _last_samp := 0.0
var _last_pos_dump := 0.0
var _last_combo := -1
var _frozen_t := 0.0
var _last_my_turn := true
var _not_my_turn_t := 0.0
var _prev_positions: Dictionary = {}
var _pos_check_t := 0.0
var _prev_moving: Dictionary = {}
var _lobby_retry_t := 0.0
var _lobby_attempts := 0
var _join_retry_t := 0.0
var _join_attempts := 0
var _in_battle_scene := false

const TOTAL_TIMEOUT := 600.0
const FREEZE_TIMEOUT := 90.0

func _ready():
	for a in OS.get_cmdline_args():
		if a.begins_with("--nettest="):
			var v = a.trim_prefix("--nettest=")
			var parts = v.split(":")
			if parts.size() >= 2:
				role = parts[0]
				scenario = parts[1]
	if role != "":
		_apply_scenario()
		print("[NetTest] 探针启动 role=%s scenario=%s 参数: suicide_t=%s surrender_t=%s auto_delay=%s join_delay=%s" % [
			role, scenario, _suicide_t, _surrender_t, _auto_delay, _join_delay])

func _apply_scenario():
	match scenario:
		"s4":
			if role == "client":
				_suicide_t = 8.0
		"s5":
			if role == "client":
				_join_delay = -1.0  # 永不进场
		"s6":
			if role == "client":
				_join_delay = 12.0
		"s7":
			if role == "client":
				_surrender_t = 12.0
		"s9":
			_auto_delay = 8.0
		"s11":
			if role == "host":
				_suicide_t = 8.0

func _log(msg: String):
	print("[NetTest] %s" % msg)

func _process(delta):
	if role == "":
		return
	_time += delta
	if _time > TOTAL_TIMEOUT:
		_log("总超时(%ds)，结束。场景=%s" % [TOTAL_TIMEOUT, _scene_path])
		_dump_state(get_tree().current_scene)
		get_tree().quit(43)
		return
	var scene = get_tree().current_scene
	if not scene:
		return
	var sp = scene.get_script().resource_path if scene.get_script() else ""
	if sp != _scene_path:
		_scene_path = sp
		if sp.ends_with("Menus/MainMenu.gd"):
			_on_menu(scene)
		elif sp.ends_with("Scenes/main.gd"):
			_on_battle(scene)
			_in_battle_scene = true
	# 建服/加入失败重试（端口探测与创建之间的竞态兜底）
	if sp.ends_with("Menus/MainMenu.gd"):
		if role == "host" and _host_started and not _in_battle_scene:
			_lobby_retry_t += delta
			if _lobby_retry_t > 3.0 and _lobby_attempts < 5:
				_lobby_retry_t = 0.0
				var menu = scene
				if menu.get("_lobby_active") == false or not (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
					_lobby_attempts += 1
					_log("建服未就绪（第 %d 次重试），重新创建房间" % _lobby_attempts)
					_cleanup_peer(menu)
					menu._on_host_pressed()
					_write_port_file()
		elif role == "client" and _client_started and not _in_battle_scene \
				and scenario != "s3" and scenario != "s5" and scenario != "s6":
			# 延迟进场场景（s3/s5/s6）走 _start_delayed_join，连接已成功，不做加入重试
			_join_retry_t += delta
			if _join_retry_t > 8.0 and _join_attempts < 5:
				_join_retry_t = 0.0
				_join_attempts += 1
				_log("连接未成功（第 %d 次重试）" % _join_attempts)
				_cleanup_peer(scene)
				var port = _read_port_file()
				GlobalGameData.server_port = port
				scene._on_connect_to_room("127.0.0.1")
	if sp.ends_with("Scenes/main.gd"):
		_tick_battle(scene, delta)

func _cleanup_peer(menu):
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if menu and menu.has_method("_cleanup_multiplayer_peer"):
		menu._cleanup_multiplayer_peer()

func _write_port_file():
	var f = FileAccess.open("C:/Users/10932/Documents/GodotProject/destiny-dawn/tests/logs/port.txt", FileAccess.WRITE)
	if f:
		f.store_line(str(GlobalGameData.server_port))
		f.close()

func _read_port_file() -> int:
	var port = 1145
	var f = FileAccess.open("C:/Users/10932/Documents/GodotProject/destiny-dawn/tests/logs/port.txt", FileAccess.READ)
	if f:
		var line = f.get_line().strip_edges()
		f.close()
		if line.is_valid_int():
			port = line.to_int()
	return port

# ---------------- 主菜单阶段 ----------------

func _on_menu(menu):
	_log("进入主菜单")
	if role == "host":
		if not _host_started:
			_host_started = true
			if scenario == "s1full":
				_solo_phase = true
				_log("s1full：先真实打一局单机自动战斗（用户完整路径）")
				menu._on_solo_pressed()
			else:
				_stale_setup()
				_log("创建联机房间（走真实 MainMenu 主机流程）")
				menu._on_host_pressed()
				_write_port_file()
		elif _solo_phase:
			# 单机打完回到主菜单 → 开联机
			_solo_phase = false
			_log("单机已结束回到主菜单，is_ai_mode=%s（残留），开始创建联机房间" % GlobalGameData.is_ai_mode)
			menu._on_host_pressed()
			_write_port_file()
		elif scenario == "s8" and _games_played >= 1 and _games_played < 2:
			# s8 第二局：打完第一局回菜单再开房（同进程状态残留验证）
			_log("s8：第二局重新创建房间（同进程，第 %d 局前）" % _games_played)
			menu._on_host_pressed()
			_write_port_file()
		elif scenario == "s12" and _mp_done and not _solo_started:
			# s12：联机局打完回菜单 → 开单机（验证联机残留不影响单机）
			_solo_started = true
			_solo_phase = true
			_log("s12：联机局已结束，is_ai_mode=%s，开始单机局" % GlobalGameData.is_ai_mode)
			menu._on_solo_pressed()
	elif role == "client":
		if not _client_started:
			_client_started = true
			if scenario == "s2":
				GlobalGameData.is_ai_mode = true
				_log("注入残留状态 is_ai_mode=true（模拟刚打完单机）")
			if scenario == "s3" or scenario == "s5" or scenario == "s6":
				_log("%s：直接建 client peer（join_delay=%s）" % [scenario, _join_delay])
				_start_delayed_join()
			else:
				# 读取 host 实际端口（host 写入 port.txt）
				var port = _read_port_file()
				_log("加入房间 127.0.0.1:%d（走真实 MainMenu 加入流程）" % port)
				GlobalGameData.server_port = port
				menu._on_connect_to_room("127.0.0.1")
		elif scenario == "s8" and _games_played >= 1 and _games_played < 2:
			# s8 第二局：打完第一局回菜单再加入
			_log("s8：第二局重新加入（同进程，第 %d 局前）" % _games_played)
			var port = _read_port_file()
			GlobalGameData.server_port = port
			menu._on_connect_to_room("127.0.0.1")
		elif scenario == "s11" and _was_in_battle:
			_log("s11：主机掉线后客户端已回主菜单，验证通过")
			get_tree().quit(0)

func _stale_setup():
	if scenario == "s1":
		GlobalGameData.is_ai_mode = true
		_log("注入残留状态 is_ai_mode=true（模拟刚打完单机）")

func _start_delayed_join():
	var port = _read_port_file()
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", port) != OK:
		_log("create_client 失败")
		get_tree().quit(44)
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = false
	multiplayer.connected_to_server.connect(_on_delayed_connected)

func _on_delayed_connected():
	_log("connected_to_server 触发")
	if scenario == "s5":
		# 模拟"卡在加载/永不就绪"的客户端：不进入战斗场景、不回执 ready。
		# 保持连接 45s（> 主机 30s setup 超时），观察主机超时结算行为
		_log("s5：客户端不进入战斗场景（模拟卡死客户端），45s 后退出观察主机行为")
		await get_tree().create_timer(45.0).timeout
		get_tree().quit(0)
		return
	_log("延迟 %s 秒后进入战斗场景（期间主机的一波同步 RPC 会丢失）" % _join_delay)
	await get_tree().create_timer(_join_delay).timeout
	BackgroundSingleton.enter_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

# ---------------- 战斗阶段 ----------------

func _on_battle(scene):
	_battle_t = _time
	_last_samp = _time
	_last_pos_dump = _time
	_auto_on = false
	_over_reported = false
	_suicided = false
	_surrender_done = false
	_last_combo = -1
	_frozen_t = 0.0
	_not_my_turn_t = 0.0
	_was_in_battle = true
	if scenario == "s8":
		_games_played += 1
		_log("s8：第 %d 局开始" % _games_played)
	_log("进入战斗场景 | is_ai_mode=%s is_host=%s has_peer=%s is_server=%s unique_id=%s peers=%s client_peer_id=%s pending_client_id=%s 队伍=%s" % [
		GlobalGameData.is_ai_mode, GlobalGameData.is_host,
		multiplayer.has_multiplayer_peer(),
		multiplayer.is_server() if multiplayer.has_multiplayer_peer() else "n/a",
		multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else "n/a",
		multiplayer.get_peers() if multiplayer.has_multiplayer_peer() else [],
		GlobalGameData.client_peer_id, GlobalGameData.pending_client_id,
		GlobalGameData.selected_team])

func _tick_battle(scene, delta):
	# 开启自动战斗（AI 对 AI，双端；s9 延迟开启验证中途接管）
	if not _auto_on and _time - _battle_t > _auto_delay:
		if scene.has_method("_toggle_auto_battle"):
			scene._toggle_auto_battle()
			_auto_on = true
			_log("已开启本端自动战斗（auto_battle_self=%s）" % GlobalGameData.auto_battle_self)

	# 自杀模拟掉线（s4 client / s11 host；对局已结束则不自杀）
	if _suicide_t > 0.0 and not _suicided and not scene._battle_over and _time - _battle_t > _suicide_t:
		_suicided = true
		_log("模拟掉线：本端进程退出（%s）" % role)
		get_tree().quit(77)

	# 投降（s7 client；对局已结束则不投降）
	if _surrender_t > 0.0 and not _surrender_done and not scene._battle_over and _time - _battle_t > _surrender_t:
		_surrender_done = true
		_log("模拟玩家投降（调用 _confirm_surrender）")
		scene._confirm_surrender()

	# s1full/s12 单机阶段：s1full 打完回主菜单继续联机；s12 打完验证后退出
	if _solo_phase:
		if not _over_reported and scene._battle_over:
			_over_reported = true
			if scenario == "s12":
				_log("s12：单机局结束（battle_over），联机→单机链路验证通过")
				_dump_state(scene)
				await get_tree().create_timer(2.0).timeout
				get_tree().quit(0)
				return
			_log("单机自动战斗结束（battle_over），返回主菜单")
			var br = scene.get_node_or_null("UI/BattleResult")
			if br and br.has_method("_on_return_pressed"):
				br._on_return_pressed()
		return

	# 正常联机阶段：结算退出（s8 打完回菜单开下一局；s12 打完回菜单开单机）
	if not _over_reported and scene._battle_over:
		_over_reported = true
		_log("BATTLE-OVER 本端结算，phase=%s is_host_turn=%s" % [_phase_name(GlobalGameData.current_turn_phase), GlobalGameData.is_host_turn])
		_dump_state(scene)
		if scenario == "s8" and _games_played < 2:
			_log("s8：本局结束，返回主菜单准备下一局")
			await get_tree().create_timer(2.0).timeout
			var br = scene.get_node_or_null("UI/BattleResult")
			if br and br.has_method("_on_return_pressed"):
				br._on_return_pressed()
			return
		if scenario == "s12" and not _mp_done:
			_mp_done = true
			_log("s12：联机局结束，返回主菜单准备单机局")
			await get_tree().create_timer(2.0).timeout
			var br = scene.get_node_or_null("UI/BattleResult")
			if br and br.has_method("_on_return_pressed"):
				br._on_return_pressed()
			return
		await get_tree().create_timer(2.0).timeout
		get_tree().quit(0)
		return

	# 周期采样
	if _time - _last_samp >= 1.0:
		_last_samp = _time
		var names = []
		for c in scene.characters:
			names.append("%s(hp%d)" % [c.name, c.hp])
		_log("采样 t=%.0f phase=%s host_turn=%s my_turn=%s chars=%d %s" % [
			_time, _phase_name(GlobalGameData.current_turn_phase), GlobalGameData.is_host_turn,
			scene.is_my_turn(), scene.characters.size(), names])
		var poss = []
		for c in scene.characters:
			poss.append("%s@%s" % [c.name, c.global_position.round()])
		_log("位置 %s" % [poss])

	# is_moving / target_world 变化监控（每帧）
	for c in scene.characters:
		if not is_instance_valid(c):
			continue
		var mv: bool = c.get("is_moving")
		if _prev_moving.has(c.name) and _prev_moving[c.name] != mv:
			_log("MovingChange %s is_moving=%s target=%s" % [c.name, mv, c.get("target_world")])
		_prev_moving[c.name] = mv

	# 高频位置变化检测（50ms）
	_pos_check_t += delta
	if _pos_check_t >= 0.05:
		_pos_check_t = 0.0
		for c in scene.characters:
			if not is_instance_valid(c):
				continue
			var key: String = "%s#%d" % [c.name, c.get_instance_id()]
			var cur: Vector2 = c.global_position
			if _prev_positions.has(key):
				var prev: Vector2 = _prev_positions[key]
				if prev.distance_to(cur) > 1.0:
					_log("PosChange %s %s -> %s vel=%s moving=%s target=%s authority=%s phase=%s" % [
						key, prev.round(), cur.round(), c.velocity, c.is_moving,
						c.target_world.round(), c.is_multiplayer_authority(),
						_phase_name(GlobalGameData.current_turn_phase)])
			_prev_positions[key] = cur

	# 卡死检测
	var phase = GlobalGameData.current_turn_phase
	var combo = phase * 10 + (1 if GlobalGameData.is_host_turn else 0)
	if combo != _last_combo:
		_last_combo = combo
		_frozen_t = 0.0
	var my_turn = scene.is_my_turn()
	if my_turn != _last_my_turn:
		_last_my_turn = my_turn
		_not_my_turn_t = 0.0
	if phase == GlobalGameData.TurnPhase.PLAYER_TURN or phase == GlobalGameData.TurnPhase.ENEMY_TURN:
		_frozen_t += delta
		if not my_turn:
			_not_my_turn_t += delta
	if _frozen_t > FREEZE_TIMEOUT:
		_log("FREEZE：相位/先手状态 %ds 无变化（疑似卡死）" % FREEZE_TIMEOUT)
		_dump_state(scene)
		get_tree().quit(42)
		return
	if _not_my_turn_t > FREEZE_TIMEOUT:
		_log("FREEZE：本端连续 %ds 显示非本端回合（疑似双端都停在对方回合）" % FREEZE_TIMEOUT)
		_dump_state(scene)
		get_tree().quit(42)

func _phase_name(p: int) -> String:
	match p:
		GlobalGameData.TurnPhase.NONE: return "NONE"
		GlobalGameData.TurnPhase.START_ROUND: return "START_ROUND"
		GlobalGameData.TurnPhase.PLAYER_TURN: return "PLAYER_TURN"
		GlobalGameData.TurnPhase.ENEMY_TURN: return "ENEMY_TURN"
		GlobalGameData.TurnPhase.GAME_OVER: return "GAME_OVER"
	return "?"

func _dump_state(scene):
	_log("==== 状态快照 ====")
	if not scene:
		_log("（无当前场景）")
		return
	_log("is_ai_mode=%s is_host=%s phase=%s host_turn=%s my_turn=%s battle_over=%s client_peer_id=%s" % [
		GlobalGameData.is_ai_mode, GlobalGameData.is_host, _phase_name(GlobalGameData.current_turn_phase),
		GlobalGameData.is_host_turn, scene.is_my_turn(), scene._battle_over, GlobalGameData.client_peer_id])
	for c in scene.characters:
		_log("  角色 %s hp=%d pos=%s charPhase=%s ownerPid=%s" % [
			c.name, c.hp, c.global_position.round(), c.get_current_phase(), c.owner_pid])
