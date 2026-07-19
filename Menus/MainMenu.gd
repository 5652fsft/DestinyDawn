extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

func _ready():
	GlobalGameData.load_defaults_if_empty()
	var buttons = [$VBoxContainer/TeamButton, $VBoxContainer/DeckButton, $VBoxContainer/HostButton, $VBoxContainer/JoinButton, $VBoxContainer/SettingsButton, $VBoxContainer/QuitButton]
	for btn in buttons:
		btn.mouse_entered.connect(_on_btn_enter.bind(btn))
		btn.mouse_exited.connect(_on_btn_exit.bind(btn))
		btn.button_down.connect(_on_btn_down.bind(btn))
		btn.button_up.connect(_on_btn_up.bind(btn))
		btn.pivot_offset = btn.size * 0.5
	call_deferred("_center_button_pivots")
	_update_status()

func _center_button_pivots():
	for btn in [$VBoxContainer/TeamButton, $VBoxContainer/DeckButton, $VBoxContainer/HostButton, $VBoxContainer/JoinButton, $VBoxContainer/SettingsButton, $VBoxContainer/QuitButton]:
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size * 0.5

func _update_status():
	var team = GlobalGameData.selected_team
	var deck = GlobalGameData.selected_deck
	$VBoxContainer/TeamButton.text = "编队管理 (%d/3)" % team.size()
	$VBoxContainer/DeckButton.text = "卡组构筑 (%d/8)" % deck.size()

func _on_btn_enter(btn):
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_btn_exit(btn):
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1, 1), 0.1)

func _on_btn_down(btn):
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.05)

func _on_btn_up(btn):
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.05)

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

func _on_quit_pressed():
	get_tree().quit()
