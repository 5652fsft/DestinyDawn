extends Control

const FONT = preload("res://Assets/Fronts/SourceHanSerifCN-Heavy-4.otf")

@onready var team_status = $VBoxContainer/TeamStatus
@onready var deck_status = $VBoxContainer/DeckStatus

func _ready():
	_update_status()

func _update_status():
	var team_count = GlobalGameData.selected_team.size()
	var deck_count = GlobalGameData.selected_deck.size()
	team_status.text = "编队: %d/3 名角色" % team_count if team_count > 0 else "编队: 未配置"
	deck_status.text = "卡组: %d 张牌" % deck_count if deck_count > 0 else "卡组: 未配置"

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
	$IPDialog.popup_centered()

func _on_ip_confirm():
	var ip = $IPDialog/IPLineEdit.text
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
	$SettingsPanel.show()

func _on_settings_close():
	GlobalGameData.player_name = $SettingsPanel/NameEdit.text
	$SettingsPanel.hide()
	_update_status()

func _on_quit_pressed():
	get_tree().quit()
