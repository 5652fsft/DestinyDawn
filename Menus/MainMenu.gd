extends Control

func _ready():
	GlobalGameData.load_defaults_if_empty()
	var buttons = [$VBoxContainer/TeamButton, $VBoxContainer/DeckButton, $VBoxContainer/HostButton, $VBoxContainer/JoinButton, $VBoxContainer/AIBattleButton, $VBoxContainer/GuideButton, $VBoxContainer/SettingsButton, $VBoxContainer/QuitButton]
	for btn in buttons:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.set_font(btn, 20)
	_update_status()

func _update_status():
	$VBoxContainer/TeamButton.text = "编队管理"
	$VBoxContainer/DeckButton.text = "卡组构筑"

func _on_team_pressed():
	get_tree().change_scene_to_file("res://Menus/TeamFormation.tscn")

func _on_deck_pressed():
	get_tree().change_scene_to_file("res://Menus/DeckBuilder.tscn")

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(1145) != OK:
		print("[Error] 服务器启动失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = true
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_join_pressed():
	var ip = GlobalGameData.server_ip
	if ip.is_empty():
		ip = "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, 1145) != OK:
		print("[Error] 连接失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = false
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://Menus/SettingsScene.tscn")

func _on_ai_battle_pressed():
	GlobalGameData.load_defaults_if_empty()
	GlobalGameData.is_host = true
	GlobalGameData.is_ai_mode = true
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_guide_pressed():
	get_tree().change_scene_to_file("res://Menus/GuideScene.tscn")

func _on_quit_pressed():
	get_tree().quit()
