extends Control

# --- 联机状态 ---
var _lobby_active: bool = false
var _my_public_ip: String = ""
var _my_local_ip: String = ""
var _my_vpn_ip: String = ""
var _server_port: int = 1145
var _upnp_success: bool = false
var _http_request: HTTPRequest = null
var _http_timeout: Timer = null
var _pending_urls: Array[String] = []
var _join_timer: Timer = null

const DEFAULT_PORT = 1145
const PORT_RANGE = 10

# --- UI 节点引用 ---
@onready var lobby_backdrop = $LobbyBackdrop
@onready var lobby_panel = $LobbyPanel
@onready var room_code_label = $LobbyPanel/VBox/RoomCodeLabel
@onready var local_ip_label = $LobbyPanel/VBox/LocalIPLabel
@onready var upnp_status_label = $LobbyPanel/VBox/UpnpStatusLabel
@onready var wait_status_label = $LobbyPanel/VBox/WaitStatusLabel
@onready var copy_button = $LobbyPanel/VBox/LobbyButtonRow/CopyButton
@onready var cancel_host_button = $LobbyPanel/VBox/LobbyButtonRow/CancelHostButton

@onready var join_backdrop = $JoinBackdrop
@onready var join_panel = $JoinPanel
@onready var room_code_input = $JoinPanel/VBox/InputRow/RoomCodeInput
@onready var join_status_label = $JoinPanel/VBox/JoinStatusLabel
@onready var connect_button = $JoinPanel/VBox/JoinButtonRow/ConnectButton
@onready var cancel_join_button = $JoinPanel/VBox/JoinButtonRow/CancelJoinButton
@onready var how_to_connect = $JoinPanel/VBox/HowToConnect


func _ready():
	_cleanup_multiplayer_peer()
	GlobalGameData.load_defaults_if_empty()

	# 应用按钮样式
	var main_buttons = [
		$ButtonPanel/TopRow/TeamButton,
		$ButtonPanel/TopRow/DeckButton,
		$ButtonPanel/SoloButton,
		$ButtonPanel/OnlineFrame/OnlineRow/HostButton,
		$ButtonPanel/OnlineFrame/OnlineRow/JoinButton
	]
	for btn in main_buttons:
		ButtonTheme.apply_menu(btn)

	# 左上角小按钮
	ButtonTheme.apply_menu($SettingsButton)
	ButtonTheme.apply_menu($GuideButton)
	$SettingsButton.icon = preload("res://Assets/Icons/settings.png")
	$SettingsButton.text = ""
	$SettingsButton.expand_icon = true
	$GuideButton.icon = preload("res://Assets/Icons/info.png")
	$GuideButton.text = ""
	$GuideButton.expand_icon = true

	# 毛玻璃样式
	_apply_glass_style()

	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

	# 联机面板按钮信号
	copy_button.pressed.connect(_on_copy_room_code)
	cancel_host_button.pressed.connect(_on_cancel_host)
	connect_button.pressed.connect(_on_connect_to_room)
	cancel_join_button.pressed.connect(_on_cancel_join)
	room_code_input.text_submitted.connect(_on_connect_to_room)
	how_to_connect.pressed.connect(_on_how_to_connect)


func _apply_glass_style():
	# 灰底毛玻璃（编队/卡组/联机框）
	var style_gray = StyleBoxFlat.new()
	style_gray.bg_color = Color(0.4, 0.4, 0.43, 0.45)
	style_gray.border_width_top = 1
	style_gray.border_width_bottom = 1
	style_gray.border_width_left = 1
	style_gray.border_width_right = 1
	style_gray.border_color = Color(0.6, 0.6, 0.65, 0.4)
	style_gray.corner_radius_top_left = 10
	style_gray.corner_radius_top_right = 10
	style_gray.corner_radius_bottom_left = 10
	style_gray.corner_radius_bottom_right = 10
	$ButtonPanel/TopRow/TeamButton.add_theme_stylebox_override("normal", style_gray)
	$ButtonPanel/TopRow/DeckButton.add_theme_stylebox_override("normal", style_gray)
	$ButtonPanel/OnlineFrame.add_theme_stylebox_override("panel", style_gray)

	# 蓝底毛玻璃（单人/联机按钮）
	var style_blue = StyleBoxFlat.new()
	style_blue.bg_color = Color(0.32, 0.4, 0.52, 0.45)
	style_blue.border_width_top = 1
	style_blue.border_width_bottom = 1
	style_blue.border_width_left = 1
	style_blue.border_width_right = 1
	style_blue.border_color = Color(0.5, 0.55, 0.65, 0.4)
	style_blue.corner_radius_top_left = 10
	style_blue.corner_radius_top_right = 10
	style_blue.corner_radius_bottom_left = 10
	style_blue.corner_radius_bottom_right = 10
	$ButtonPanel/SoloButton.add_theme_stylebox_override("normal", style_blue)
	$ButtonPanel/OnlineFrame/OnlineRow/HostButton.add_theme_stylebox_override("normal", style_blue)
	$ButtonPanel/OnlineFrame/OnlineRow/JoinButton.add_theme_stylebox_override("normal", style_blue)

	# 悬停效果
	var style_hover_gray = style_gray.duplicate()
	style_hover_gray.bg_color = Color(0.45, 0.45, 0.48, 0.55)
	$ButtonPanel/TopRow/TeamButton.add_theme_stylebox_override("hover", style_hover_gray)
	$ButtonPanel/TopRow/DeckButton.add_theme_stylebox_override("hover", style_hover_gray)

	var style_hover_blue = style_blue.duplicate()
	style_hover_blue.bg_color = Color(0.38, 0.46, 0.58, 0.55)
	$ButtonPanel/SoloButton.add_theme_stylebox_override("hover", style_hover_blue)
	$ButtonPanel/OnlineFrame/OnlineRow/HostButton.add_theme_stylebox_override("hover", style_hover_blue)
	$ButtonPanel/OnlineFrame/OnlineRow/JoinButton.add_theme_stylebox_override("hover", style_hover_blue)

	# 左上角小按钮样式
	var style_icon = StyleBoxFlat.new()
	style_icon.bg_color = Color(0.15, 0.15, 0.18, 0.6)
	style_icon.border_width_top = 1
	style_icon.border_width_bottom = 1
	style_icon.border_width_left = 1
	style_icon.border_width_right = 1
	style_icon.border_color = Color(0.3, 0.3, 0.35, 0.5)
	style_icon.corner_radius_top_left = 6
	style_icon.corner_radius_top_right = 6
	style_icon.corner_radius_bottom_left = 6
	style_icon.corner_radius_bottom_right = 6
	$SettingsButton.add_theme_stylebox_override("normal", style_icon)
	$GuideButton.add_theme_stylebox_override("normal", style_icon)

	var style_icon_hover = style_icon.duplicate()
	style_icon_hover.bg_color = Color(0.2, 0.2, 0.25, 0.7)
	$SettingsButton.add_theme_stylebox_override("hover", style_icon_hover)
	$GuideButton.add_theme_stylebox_override("hover", style_icon_hover)

	# 联机覆盖层面板样式
	var style_overlay = StyleBoxFlat.new()
	style_overlay.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style_overlay.border_width_top = 2
	style_overlay.border_width_bottom = 1
	style_overlay.border_width_left = 1
	style_overlay.border_width_right = 1
	style_overlay.border_color = Color(0.5, 0.55, 0.7, 0.5)
	style_overlay.corner_radius_top_left = 14
	style_overlay.corner_radius_top_right = 14
	style_overlay.corner_radius_bottom_left = 14
	style_overlay.corner_radius_bottom_right = 14
	style_overlay.shadow_color = Color(0, 0, 0, 0.4)
	style_overlay.shadow_size = 12
	lobby_panel.add_theme_stylebox_override("panel", style_overlay)
	join_panel.add_theme_stylebox_override("panel", style_overlay)

	# 联机面板按钮样式
	for btn in [copy_button, cancel_host_button, connect_button, cancel_join_button]:
		ButtonTheme.apply_menu(btn)

	# RoomCodeInput 字体
	var font_input = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
	room_code_input.add_theme_font_override("font", font_input)
	room_code_input.add_theme_font_size_override("font_size", 16)


func _on_team_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/TeamFormation.tscn")


func _on_deck_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/DeckBuilder.tscn")


func _cleanup_multiplayer_peer():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func _on_solo_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	_cleanup_multiplayer_peer()
	GlobalGameData.load_defaults_if_empty()
	GlobalGameData.is_host = true
	GlobalGameData.is_ai_mode = true
	BackgroundSingleton.enter_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")


# ============================================================
#  主机流程（UPnP + 房间码）
# ============================================================

func _on_host_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	_cleanup_multiplayer_peer()

	# 断开旧信号，防止重复连接
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

	_server_port = GlobalGameData.server_port
	_my_local_ip = _get_lan_ip()
	_my_vpn_ip = _get_vpn_ip()
	_my_public_ip = ""
	_upnp_success = false

	_lobby_active = true
	_show_lobby_ui(true)
	_set_lobby_status("正在设置联机...", false)
	room_code_label.text = "你的房间码：——"
	local_ip_label.text = ""
	upnp_status_label.text = ""

	# 尝试可用端口
	var port = _try_find_port()
	if port == -1:
		_set_lobby_status("❌ 端口不可用，请更换端口", false)
		return
	_server_port = port

	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(_server_port) != OK:
		_set_lobby_status("❌ 服务器创建失败", false)
		return

	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = true

	# 连接信号（等待玩家加入）
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 启动 UPnP
	_setup_upnp()

	# 同时通过 HTTP 获取公网 IP（UPnP 可能失败或未返回外网 IP）
	_fetch_public_ip_http()

	# 立即用本地 IP 显示房间码（不等公网 IP）
	_update_lobby_ui()


func _try_find_port() -> int:
	var base = GlobalGameData.server_port
	for offset in range(PORT_RANGE):
		var p = base + offset
		var test_peer = ENetMultiplayerPeer.new()
		if test_peer.create_server(p) == OK:
			test_peer.close()
			return p
		test_peer.close()
	return -1


func _setup_upnp():
	upnp_status_label.text = "正在检测 UPnP..."
	var upnp = UPNP.new()
	var discover_result = upnp.discover()

	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		upnp_status_label.text = "⚠ UPnP 失败，需手动端口转发或用 VPN"
		print("[UPnP] 发现失败: ", discover_result)
		return

	var gateway = upnp.get_gateway()
	if not gateway:
		upnp_status_label.text = "⚠ UPnP 未找到网关，需手动端口转发或用 VPN"
		return

	# 删除旧映射后重新添加
	upnp.delete_port_mapping(_server_port, "UDP")
	var map_result = upnp.add_port_mapping(_server_port, 0, "DestinyDawn", "UDP")

	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		upnp_status_label.text = "⚠ UPnP 端口映射失败（可在路由器手动设置）"
		print("[UPnP] 映射失败: ", map_result)
		return

	_upnp_success = true
	var ext_ip = upnp.query_external_address()
	if ext_ip and not ext_ip.is_empty():
		_my_public_ip = ext_ip
		upnp_status_label.text = "✅ UPnP 端口映射成功"
	else:
		upnp_status_label.text = "✅ UPnP 映射成功，正在获取公网 IP..."
	print("[UPnP] 成功，外网 IP: ", _my_public_ip)

	_update_lobby_ui()


func _fetch_public_ip_http():
	_pending_urls = [
		"https://api.ipify.org?format=text",
		"https://ipinfo.io/ip",
		"https://myexternalip.com/raw",
	]
	_try_next_ip_url()


func _try_next_ip_url():
	if _pending_urls.is_empty():
		# 所有 URL 都试完了
		if _my_public_ip.is_empty():
			upnp_status_label.text = "⚠ 获取公网 IP 失败（局域网可用）"
			_update_lobby_ui()
		return

	var url = _pending_urls.pop_front()
	if _http_request:
		_http_request.queue_free()
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_ip_fetch_completed)

	var err = _http_request.request(url)
	if err != OK:
		_try_next_ip_url()
		return

	# 5 秒超时
	if _http_timeout:
		_http_timeout.queue_free()
	_http_timeout = Timer.new()
	_http_timeout.one_shot = true
	_http_timeout.wait_time = 5.0
	_http_timeout.timeout.connect(_on_ip_timeout)
	add_child(_http_timeout)
	_http_timeout.start()


func _on_ip_timeout():
	if _http_request:
		_http_request.queue_free()
		_http_request = null
	_http_timeout = null
	if _my_public_ip.is_empty():
		_try_next_ip_url()


func _on_ip_fetch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	# 停止超时计时器
	if _http_timeout:
		_http_timeout.queue_free()
		_http_timeout = null

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var ip = body.get_string_from_utf8().strip_edges()
		if not ip.is_empty():
			_my_public_ip = ip
			print("[HTTP] 获取公网 IP: ", _my_public_ip)
			# 成功，清理
			if _http_request:
				_http_request.queue_free()
				_http_request = null
			_pending_urls.clear()
			_update_lobby_ui()
			return

	# 当前 URL 失败，试下一个
	_try_next_ip_url()


func _get_lan_ip() -> String:
	# 普通局域网 IP（排除 VPN 虚拟 IP）
	for ip in IP.get_local_addresses():
		var first = ip.get_slice(".", 0)
		if first == "26" or first == "27" or first == "28" or first == "10":
			continue
		if ip != "127.0.0.1" and not ip.begins_with("169.254") and ip.count(".") == 3:
			return ip
	return "127.0.0.1"

func _get_vpn_ip() -> String:
	for ip in IP.get_local_addresses():
		var first = ip.get_slice(".", 0)
		if first == "26" or first == "27" or first == "28" or first == "10":
			if ip.count(".") == 3:
				return ip
	return ""


func _update_lobby_ui():
	if not _lobby_active:
		return

	# 房间码 = VPN IP > 公网 IP > 局域网 IP > 127.0.0.1
	var room_ip = _my_vpn_ip if not _my_vpn_ip.is_empty() else (_my_public_ip if not _my_public_ip.is_empty() else _my_local_ip)
	room_code_label.text = "你的房间码：%s:%d" % [room_ip, _server_port]

	# 备用地址
	var extras = []
	if _my_vpn_ip and not _my_public_ip.is_empty():
		extras.append("外网 %s:%d" % [_my_public_ip, _server_port])
	if _my_vpn_ip and _my_local_ip != "127.0.0.1":
		extras.append("局域网 %s:%d" % [_my_local_ip, _server_port])
	if _my_vpn_ip.is_empty() and not _my_public_ip.is_empty() and _my_local_ip != "127.0.0.1":
		extras.append("局域网备用 %s:%d" % [_my_local_ip, _server_port])
	local_ip_label.text = "  ".join(extras) if extras else ""

	var has_pending_http = _http_request != null or not _pending_urls.is_empty()
	var need_port_fwd = not _upnp_success and not _my_public_ip.is_empty()
	if _my_public_ip.is_empty():
		if has_pending_http:
			_set_lobby_status("正在获取公网 IP...", false)
		else:
			_set_lobby_status("等待队友加入...", false)
			upnp_status_label.text = "⚠ 未获取到公网 IP（局域网或 VPN 可用）"
	else:
		_set_lobby_status("等待队友加入...", false)
		if need_port_fwd:
			upnp_status_label.text = "⚠ 外网联机需路由器端口转发或使用 VPN"


func _on_peer_connected(id: int):
	if not _lobby_active:
		return
	print("[Host] 玩家加入，peer_id: ", id)
	GlobalGameData.pending_client_id = id
	_set_lobby_status("✅ 队友已加入！进入战斗...", true)

	# 断开 lobby 信号，避免切场景后误触发
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

	_lobby_active = false
	_hide_lobby_ui()

	BackgroundSingleton.enter_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")


func _on_peer_disconnected(id: int):
	if not _lobby_active:
		return
	print("[Host] 玩家断开，peer_id: ", id)
	_set_lobby_status("队友已断开连接，等待重新加入...", false)


func _show_lobby_ui(show: bool):
	lobby_backdrop.visible = show
	lobby_panel.visible = show


func _hide_lobby_ui():
	lobby_backdrop.visible = false
	lobby_panel.visible = false


func _set_lobby_status(text: String, is_success: bool):
	wait_status_label.text = text
	if is_success:
		wait_status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	else:
		wait_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))


func _on_copy_room_code():
	var code = room_code_label.text.replace("你的房间码：", "")
	DisplayServer.clipboard_set(code)
	copy_button.text = "✅ 已复制"
	await get_tree().create_timer(2.0).timeout
	copy_button.text = "复制房间码"


func _on_cancel_host():
	_lobby_active = false
	GlobalGameData.pending_client_id = -1
	_cleanup_multiplayer_peer()
	if _http_request:
		_http_request.queue_free()
		_http_request = null
	if _http_timeout:
		_http_timeout.queue_free()
		_http_timeout = null
	_pending_urls.clear()
	# 断开信号
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	_hide_lobby_ui()


# ============================================================
#  加入流程（房间码输入）
# ============================================================

func _on_join_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")

	# 显示加入面板
	join_backdrop.visible = true
	join_panel.visible = true
	join_status_label.text = ""
	room_code_input.text = ""
	connect_button.disabled = false
	room_code_input.grab_focus()


func _on_connect_to_room(quick_ip: String = ""):
	var ip = ""
	var port = GlobalGameData.server_port

	if not quick_ip.is_empty():
		# 快速连接（本地测试用）
		ip = quick_ip
		print("[Join] 快速连接: ", ip, ":", port)
	else:
		var input = room_code_input.text.strip_edges()
		if input.is_empty():
			join_status_label.text = "请输入房间码"
			return

		# 解析 IP 和端口
		ip = input
		if ":" in input:
			var parts = input.split(":")
			if parts.size() != 2 or parts[0].is_empty():
				join_status_label.text = "❌ 格式错误，示例：123.45.67.89:1145"
				return
			ip = parts[0]
			var port_str = parts[1].strip_edges()
			if not port_str.is_valid_int():
				join_status_label.text = "❌ 端口号无效"
				return
			port = port_str.to_int()
			if port <= 0 or port > 65535:
				join_status_label.text = "❌ 端口号超出范围 (1-65535)"
				return

	join_status_label.text = "正在连接 %s:%d ..." % [ip, port]
	join_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	print("[Join] 开始连接: ", ip, ":", port)

	_cleanup_multiplayer_peer()

	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		join_status_label.text = "❌ 连接失败（无法创建客户端）"
		join_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		connect_button.disabled = false
		print("[Join] create_client 返回错误")
		return

	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = false
	print("[Join] peer 已设置，等待 connected_to_server 信号...")

	# 断开旧信号（防止重复）
	if multiplayer.connected_to_server.is_connected(_on_joined_success):
		multiplayer.connected_to_server.disconnect(_on_joined_success)
	if multiplayer.connection_failed.is_connected(_on_join_failed):
		multiplayer.connection_failed.disconnect(_on_join_failed)

	# 连接信号
	multiplayer.connected_to_server.connect(_on_joined_success)
	multiplayer.connection_failed.connect(_on_join_failed)

	# 超时计时（缩短到 5 秒便于调试）
	_join_timer = Timer.new()
	_join_timer.one_shot = true
	_join_timer.wait_time = 5.0
	_join_timer.timeout.connect(_on_join_timeout)
	add_child(_join_timer)
	_join_timer.start()





func _on_joined_success():
	print("[Join] connected_to_server 信号触发！")
	if _join_timer:
		_join_timer.stop()
		_join_timer.queue_free()
		_join_timer = null

	# 断开信号，避免干扰战斗场景
	if multiplayer.connected_to_server.is_connected(_on_joined_success):
		multiplayer.connected_to_server.disconnect(_on_joined_success)
	if multiplayer.connection_failed.is_connected(_on_join_failed):
		multiplayer.connection_failed.disconnect(_on_join_failed)

	join_backdrop.visible = false
	join_panel.visible = false

	BackgroundSingleton.enter_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")


func _on_join_failed():
	print("[Join] connection_failed 信号触发！")
	if _join_timer:
		_join_timer.stop()

	join_status_label.text = "❌ 连接失败，请检查房间码是否正确"
	join_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	connect_button.disabled = false

	if multiplayer.connected_to_server.is_connected(_on_joined_success):
		multiplayer.connected_to_server.disconnect(_on_joined_success)
	if multiplayer.connection_failed.is_connected(_on_join_failed):
		multiplayer.connection_failed.disconnect(_on_join_failed)


func _on_join_timeout():
	print("[Join] 连接超时！connected_to_server 和 connection_failed 均未触发")
	if _join_timer:
		_join_timer.queue_free()
		_join_timer = null
	join_status_label.text = "⏰ 连接超时\n建议：① 检查房间码 ② 主机需开端口转发\n③ 或用 Radmin VPN / ZeroTier 组局域网"
	join_status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
	connect_button.disabled = false

	if multiplayer.connection_failed.is_connected(_on_join_failed):
		multiplayer.connection_failed.disconnect(_on_join_failed)
	if multiplayer.connected_to_server.is_connected(_on_joined_success):
		multiplayer.connected_to_server.disconnect(_on_joined_success)

	_cleanup_multiplayer_peer()


func _on_cancel_join():
	if _join_timer:
		_join_timer.stop()
		_join_timer.queue_free()
		_join_timer = null

	_cleanup_multiplayer_peer()

	if multiplayer.connected_to_server.is_connected(_on_joined_success):
		multiplayer.connected_to_server.disconnect(_on_joined_success)
	if multiplayer.connection_failed.is_connected(_on_join_failed):
		multiplayer.connection_failed.disconnect(_on_join_failed)

	join_backdrop.visible = false
	join_panel.visible = false


func _on_how_to_connect():
	var popup = AcceptDialog.new()
	popup.title = "📡 如何联机"
	popup.dialog_text = ""
	var font = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

	# 自定义内容
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	var sections = [
		{"title": "同一网络", "text": "双方连同一个 Wi-Fi 或局域网 → 直接可用", "color": Color(0.4, 1, 0.4, 1)},
		{"title": "VPN 虚拟局域网", "text": "装 Radmin VPN 或 ZeroTier（免费）\n两人加入同一虚拟网络 → 用虚拟 IP 连", "color": Color(0.4, 0.8, 1, 1)},
		{"title": "端口转发", "text": "主机在路由器设置「端口转发」\n外网 IP + 端口号才能从公网连通", "color": Color(1, 0.8, 0.4, 1)},
		{"title": "UPnP 自动", "text": "主机点「创建」时自动尝试\n路由器支持则无需手动设置", "color": Color(0.6, 0.6, 0.8, 1)},
	]
	for s in sections:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var dot = Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", s["color"])
		dot.add_theme_font_override("font", font)
		dot.add_theme_font_size_override("font_size", 14)
		dot.custom_minimum_size = Vector2(20, 0)
		hbox.add_child(dot)

		var inner = VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title = Label.new()
		title.text = s["title"]
		title.add_theme_color_override("font_color", s["color"])
		title.add_theme_font_override("font", font)
		title.add_theme_font_size_override("font_size", 16)
		inner.add_child(title)

		var desc = Label.new()
		desc.text = s["text"]
		desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
		desc.add_theme_font_override("font", font)
		desc.add_theme_font_size_override("font_size", 13)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(desc)

		hbox.add_child(inner)
		vbox.add_child(hbox)

	popup.add_child(vbox)
	popup.min_size = Vector2(480, 300)
	popup.size = Vector2(520, 360)

	# 弹窗样式
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.1, 0.14, 0.96)
	panel.border_width_top = 2
	panel.border_width_bottom = 1
	panel.border_width_left = 1
	panel.border_width_right = 1
	panel.border_color = Color(0.4, 0.45, 0.6, 0.5)
	panel.corner_radius_top_left = 12
	panel.corner_radius_top_right = 12
	panel.corner_radius_bottom_left = 12
	panel.corner_radius_bottom_right = 12
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 16
	popup.add_theme_stylebox_override("panel", panel)

	popup.popup_centered()

	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")


# ============================================================
#  其他现有功能
# ============================================================

func _on_settings_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/SettingsScene.tscn")


func _on_guide_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/GuideScene.tscn")
