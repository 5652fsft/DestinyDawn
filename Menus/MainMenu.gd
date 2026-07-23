extends Control

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

func _on_host_pressed():
	_cleanup_multiplayer_peer()
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(1145) != OK:
		print("[Error] 服务器启动失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = true
	BackgroundSingleton.enter_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_join_pressed():
	_cleanup_multiplayer_peer()
	var ip = GlobalGameData.server_ip
	if ip.is_empty():
		ip = "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, 1145) != OK:
		print("[Error] 连接失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = false
	BackgroundSingleton.enter_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_settings_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/SettingsScene.tscn")

func _on_guide_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/GuideScene.tscn")
